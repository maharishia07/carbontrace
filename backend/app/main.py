"""CarbonTrace API."""
from datetime import datetime, timedelta, timezone

from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from . import __version__
from .anomaly.detector import RECOVERY_BAND, TripSample, analyze
from .connectors import smartcar
from .database import get_db, init_db
from .emission.engine import GpsPoint, score_trip
from .emission.factors import CATALOG, resolve
from .fuel import economy_segments, update_calibration
from .models import Alert, FillUp, Trip, Vehicle
from .schemas import (
    AlertOut, DashboardOut, EconomyOut, EconomySegmentOut, FillUpIn, FillUpOut,
    HealthOut, OdometerIn, PeriodTotals, TripIn, TripOut, VehicleIn, VehicleOut,
)

app = FastAPI(title="CarbonTrace API", version=__version__)


@app.on_event("startup")
def _startup() -> None:
    init_db()


@app.get("/")
def root():
    return {"app": "CarbonTrace", "version": __version__}


@app.get("/catalog")
def catalog():
    return [
        {"key": s.key, "label": s.label, "fuel": s.fuel, "base_ef_gpkm": s.base_ef_gpkm}
        for s in CATALOG.values()
    ]


# --- vehicles ---------------------------------------------------------------

@app.post("/vehicles", response_model=VehicleOut)
def create_vehicle(body: VehicleIn, db: Session = Depends(get_db)):
    if body.class_key not in CATALOG:
        raise HTTPException(422, f"unknown class_key '{body.class_key}'")
    v = Vehicle(**body.model_dump())
    db.add(v)
    db.commit()
    return v


@app.get("/vehicles", response_model=list[VehicleOut])
def list_vehicles(db: Session = Depends(get_db)):
    return db.scalars(select(Vehicle).order_by(Vehicle.id)).all()


def _get_vehicle(db: Session, vehicle_id: int) -> Vehicle:
    v = db.get(Vehicle, vehicle_id)
    if not v:
        raise HTTPException(404, "vehicle not found")
    return v


# --- trips -------------------------------------------------------------------

def _samples(trips: list[Trip], vehicle: Vehicle | None = None) -> list[TripSample]:
    """Trips as detector samples. When the vehicle has fuel-derived
    calibration, model trips are scaled by it and count as fuel-anchored."""
    k = 1.0
    calibrated = False
    if vehicle is not None and vehicle.calibrated_at is not None:
        k = vehicle.calibration_factor or 1.0
        calibrated = True
    out = []
    for t in trips:
        idle_rate = (t.idle_co2_g / t.idle_s) if t.idle_s > 0 else 0.0
        if t.source == "model" and calibrated:
            out.append(TripSample(gpkm=t.gpkm * k, bucket=t.bucket,
                                  idle_g_per_s=idle_rate * k, source="calibrated"))
        else:
            out.append(TripSample(gpkm=t.gpkm, bucket=t.bucket,
                                  idle_g_per_s=idle_rate, source=t.source))
    return out


def _refresh_health(db: Session, vehicle: Vehicle):
    """Re-run detection after a new trip; open/close alerts on transitions."""
    trips = db.scalars(
        select(Trip).where(Trip.vehicle_id == vehicle.id).order_by(Trip.started_at)
    ).all()
    report = analyze(_samples(trips, vehicle))

    open_alert = db.scalars(
        select(Alert)
        .where(Alert.vehicle_id == vehicle.id, Alert.resolved == False)  # noqa: E712
        .order_by(Alert.created_at.desc())
    ).first()

    if report.status in ("alert", "puc_risk"):
        if not open_alert or open_alert.level != report.status:
            if open_alert:
                open_alert.resolved = True
            db.add(Alert(
                vehicle_id=vehicle.id, level=report.status,
                drift_pct=report.drift_pct, message=report.message,
            ))
    elif open_alert and report.ewma <= 1 + RECOVERY_BAND:
        open_alert.resolved = True
        db.add(Alert(
            vehicle_id=vehicle.id, level="recovered", drift_pct=report.drift_pct,
            message="Emissions are back to your baseline. Nice work getting it serviced.",
            resolved=True,  # informational notice, not an open condition
        ))
    db.commit()
    return report


@app.post("/vehicles/{vehicle_id}/trips", response_model=TripOut)
def upload_trip(vehicle_id: int, body: TripIn, db: Session = Depends(get_db)):
    vehicle = _get_vehicle(db, vehicle_id)
    spec = resolve(vehicle.class_key)
    points = [GpsPoint(p.t, p.lat, p.lon, p.speed_kmh) for p in body.points]
    try:
        r = score_trip(points, spec, cold_start=body.cold_start, fuel_litres=body.fuel_litres)
    except ValueError as e:
        raise HTTPException(422, str(e))

    started = body.started_at
    trip = Trip(
        vehicle_id=vehicle.id,
        started_at=started,
        ended_at=started + timedelta(seconds=r.duration_s),
        distance_km=r.distance_km, duration_s=r.duration_s, idle_s=r.idle_s,
        avg_moving_speed_kmh=r.avg_moving_speed_kmh,
        co2_g=r.co2_g, gpkm=r.gpkm, idle_co2_g=r.idle_co2_g,
        harsh_events=r.harsh_events, cold_start=body.cold_start,
        refuel_stop=r.refuel_stop,
        bucket=r.bucket, eco_score=r.eco_score, source=r.source,
        fuel_litres=body.fuel_litres, engine_version=r.engine_version,
    )
    db.add(trip)
    # the virtual odometer advances with every GPS trip, so fill-up
    # odometer readings are captured automatically
    if vehicle.odometer_km > 0:
        vehicle.odometer_km = round(vehicle.odometer_km + r.distance_km, 1)
    db.commit()
    _refresh_health(db, vehicle)
    db.refresh(trip)
    return trip


@app.get("/vehicles/{vehicle_id}/trips", response_model=list[TripOut])
def list_trips(vehicle_id: int, limit: int = 100, db: Session = Depends(get_db)):
    _get_vehicle(db, vehicle_id)
    return db.scalars(
        select(Trip).where(Trip.vehicle_id == vehicle_id)
        .order_by(Trip.started_at.desc()).limit(limit)
    ).all()


# --- fuel: odometer, fill-ups, measured economy, connected car ---------------

@app.post("/vehicles/{vehicle_id}/odometer", response_model=VehicleOut)
def set_odometer(vehicle_id: int, body: OdometerIn, db: Session = Depends(get_db)):
    """Set the real dashboard odometer once; GPS trips keep it current."""
    vehicle = _get_vehicle(db, vehicle_id)
    vehicle.odometer_km = body.odometer_km
    db.commit()
    return vehicle


def _recalibrate(db: Session, vehicle: Vehicle) -> None:
    fillups = db.scalars(
        select(FillUp).where(FillUp.vehicle_id == vehicle.id).order_by(FillUp.at)
    ).all()
    trips = db.scalars(
        select(Trip).where(Trip.vehicle_id == vehicle.id).order_by(Trip.started_at)
    ).all()
    segments = economy_segments(vehicle, fillups, trips)
    if segments:
        update_calibration(vehicle, segments)
    db.commit()


@app.post("/vehicles/{vehicle_id}/fillups", response_model=FillUpOut)
def add_fillup(vehicle_id: int, body: FillUpIn, db: Session = Depends(get_db)):
    """Log a refuel. Odometer auto-fills from the virtual odometer when
    omitted — litres is the only figure the user has to confirm."""
    vehicle = _get_vehicle(db, vehicle_id)
    odo = body.odometer_km if body.odometer_km is not None else vehicle.odometer_km
    if odo <= 0:
        raise HTTPException(422, "no odometer available — set the vehicle odometer once first")
    fillup = FillUp(
        vehicle_id=vehicle.id, litres=body.litres, odometer_km=odo,
        full_tank=body.full_tank, at=body.at or datetime.now(timezone.utc).replace(tzinfo=None),
        source="manual",
    )
    # keep the virtual odometer honest if the user typed the real reading
    if body.odometer_km is not None and body.odometer_km > vehicle.odometer_km:
        vehicle.odometer_km = body.odometer_km
    db.add(fillup)
    db.commit()
    _recalibrate(db, vehicle)
    _refresh_health(db, vehicle)
    db.refresh(fillup)
    return fillup


@app.get("/vehicles/{vehicle_id}/fillups", response_model=list[FillUpOut])
def list_fillups(vehicle_id: int, db: Session = Depends(get_db)):
    _get_vehicle(db, vehicle_id)
    return db.scalars(
        select(FillUp).where(FillUp.vehicle_id == vehicle_id).order_by(FillUp.at.desc())
    ).all()


@app.get("/vehicles/{vehicle_id}/economy", response_model=EconomyOut)
def economy(vehicle_id: int, db: Session = Depends(get_db)):
    vehicle = _get_vehicle(db, vehicle_id)
    fillups = db.scalars(
        select(FillUp).where(FillUp.vehicle_id == vehicle_id).order_by(FillUp.at)
    ).all()
    trips = db.scalars(
        select(Trip).where(Trip.vehicle_id == vehicle_id).order_by(Trip.started_at)
    ).all()
    segments = economy_segments(vehicle, fillups, trips)
    return EconomyOut(
        segments=[EconomySegmentOut(**s.__dict__) for s in segments],
        calibration_factor=vehicle.calibration_factor,
        calibrated_at=vehicle.calibrated_at,
        fillups=len(fillups),
    )


@app.post("/vehicles/{vehicle_id}/connected/sync", response_model=FillUpOut)
def connected_sync(vehicle_id: int, db: Session = Depends(get_db)):
    """Pull odometer + fuel-consumed from the connected-car source.

    With SMARTCAR_* env vars set this is where the real API call goes; without
    them the mock connector simulates the pull so the zero-touch data path
    works in demos. Either way the result lands as a measured fill-up record
    (source='connected') and recalibrates the vehicle."""
    vehicle = _get_vehicle(db, vehicle_id)
    if vehicle.odometer_km <= 0:
        raise HTTPException(422, "set the vehicle odometer once before syncing")
    if smartcar.configured():
        raise HTTPException(501, "real Smartcar flow requires the OAuth link step (not yet wired)")
    pull = smartcar.mock_sync(vehicle.odometer_km, seed=vehicle.id * 1000 + int(vehicle.odometer_km))
    fillup = FillUp(
        vehicle_id=vehicle.id, litres=pull["litres_consumed"],
        odometer_km=pull["odometer_km"], full_tank=True,
        at=datetime.now(timezone.utc).replace(tzinfo=None), source="connected",
    )
    vehicle.odometer_km = pull["odometer_km"]
    db.add(fillup)
    db.commit()
    _recalibrate(db, vehicle)
    _refresh_health(db, vehicle)
    db.refresh(fillup)
    return fillup


# --- health / alerts / dashboard ----------------------------------------------

@app.get("/vehicles/{vehicle_id}/health", response_model=HealthOut)
def health(vehicle_id: int, db: Session = Depends(get_db)):
    vehicle = _get_vehicle(db, vehicle_id)
    trips = db.scalars(
        select(Trip).where(Trip.vehicle_id == vehicle_id).order_by(Trip.started_at)
    ).all()
    return analyze(_samples(trips, vehicle)).__dict__


@app.get("/vehicles/{vehicle_id}/alerts", response_model=list[AlertOut])
def alerts(vehicle_id: int, db: Session = Depends(get_db)):
    _get_vehicle(db, vehicle_id)
    return db.scalars(
        select(Alert).where(Alert.vehicle_id == vehicle_id).order_by(Alert.created_at.desc())
    ).all()


@app.post("/vehicles/{vehicle_id}/serviced", response_model=AlertOut)
def mark_serviced(vehicle_id: int, db: Session = Depends(get_db)):
    _get_vehicle(db, vehicle_id)
    open_alert = db.scalars(
        select(Alert)
        .where(Alert.vehicle_id == vehicle_id, Alert.resolved == False)  # noqa: E712
        .order_by(Alert.created_at.desc())
    ).first()
    if not open_alert:
        raise HTTPException(404, "no open alert to mark serviced")
    open_alert.serviced_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(open_alert)
    return open_alert


def _totals(trips: list[Trip]) -> PeriodTotals:
    if not trips:
        return PeriodTotals(trips=0, distance_km=0.0, co2_kg=0.0, avg_gpkm=None)
    dist = sum(t.distance_km for t in trips)
    co2 = sum(t.co2_g for t in trips)
    return PeriodTotals(
        trips=len(trips),
        distance_km=round(dist, 1),
        co2_kg=round(co2 / 1000.0, 2),
        avg_gpkm=round(co2 / dist, 1) if dist > 0 else None,
    )


@app.get("/vehicles/{vehicle_id}/dashboard", response_model=DashboardOut)
def dashboard(vehicle_id: int, db: Session = Depends(get_db)):
    vehicle = _get_vehicle(db, vehicle_id)
    trips = db.scalars(
        select(Trip).where(Trip.vehicle_id == vehicle_id).order_by(Trip.started_at)
    ).all()
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    today = [t for t in trips if t.started_at >= now.replace(hour=0, minute=0, second=0, microsecond=0)]
    week = [t for t in trips if t.started_at >= now - timedelta(days=7)]
    month = [t for t in trips if t.started_at >= now - timedelta(days=30)]

    report = analyze(_samples(trips, vehicle))
    open_alert = db.scalars(
        select(Alert)
        .where(Alert.vehicle_id == vehicle_id, Alert.resolved == False)  # noqa: E712
        .order_by(Alert.created_at.desc())
    ).first()

    trend = [
        {"date": t.started_at.isoformat(), "gpkm": t.gpkm, "bucket": t.bucket}
        for t in trips[-60:]
    ]

    # auto-capture hint: recent trip had a fuel-station-like stop and no
    # fill-up has been logged since it
    refuel_hint_at = None
    recent_refuel_trips = [
        t for t in trips
        if t.refuel_stop and t.started_at >= now - timedelta(hours=48)
    ]
    if recent_refuel_trips:
        candidate = recent_refuel_trips[-1]
        fillup_since = db.scalars(
            select(FillUp).where(
                FillUp.vehicle_id == vehicle_id,
                FillUp.at >= candidate.started_at,
            )
        ).first()
        if not fillup_since:
            refuel_hint_at = candidate.started_at

    return DashboardOut(
        vehicle=VehicleOut.model_validate(vehicle),
        today=_totals(today), week=_totals(week), month=_totals(month),
        health=HealthOut(**report.__dict__),
        active_alert=AlertOut.model_validate(open_alert) if open_alert else None,
        trend=trend,
        refuel_hint_at=refuel_hint_at,
    )
