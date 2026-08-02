"""CarbonTrace API."""
from datetime import datetime, timedelta, timezone

from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from . import __version__
from .anomaly.detector import RECOVERY_BAND, TripSample, analyze
from .database import get_db, init_db
from .emission.engine import GpsPoint, score_trip
from .emission.factors import CATALOG, resolve
from .models import Alert, Trip, Vehicle
from .schemas import (
    AlertOut, DashboardOut, HealthOut, PeriodTotals, TripIn, TripOut,
    VehicleIn, VehicleOut,
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

def _samples(trips: list[Trip]) -> list[TripSample]:
    out = []
    for t in trips:
        idle_rate = (t.idle_co2_g / t.idle_s) if t.idle_s > 0 else 0.0
        out.append(TripSample(gpkm=t.gpkm, bucket=t.bucket, idle_g_per_s=idle_rate, source=t.source))
    return out


def _refresh_health(db: Session, vehicle: Vehicle):
    """Re-run detection after a new trip; open/close alerts on transitions."""
    trips = db.scalars(
        select(Trip).where(Trip.vehicle_id == vehicle.id).order_by(Trip.started_at)
    ).all()
    report = analyze(_samples(trips))

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
        bucket=r.bucket, eco_score=r.eco_score, source=r.source,
        fuel_litres=body.fuel_litres, engine_version=r.engine_version,
    )
    db.add(trip)
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


# --- health / alerts / dashboard ----------------------------------------------

@app.get("/vehicles/{vehicle_id}/health", response_model=HealthOut)
def health(vehicle_id: int, db: Session = Depends(get_db)):
    vehicle = _get_vehicle(db, vehicle_id)
    trips = db.scalars(
        select(Trip).where(Trip.vehicle_id == vehicle_id).order_by(Trip.started_at)
    ).all()
    return analyze(_samples(trips)).__dict__


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

    report = analyze(_samples(trips))
    open_alert = db.scalars(
        select(Alert)
        .where(Alert.vehicle_id == vehicle_id, Alert.resolved == False)  # noqa: E712
        .order_by(Alert.created_at.desc())
    ).first()

    trend = [
        {"date": t.started_at.isoformat(), "gpkm": t.gpkm, "bucket": t.bucket}
        for t in trips[-60:]
    ]
    return DashboardOut(
        vehicle=VehicleOut.model_validate(vehicle),
        today=_totals(today), week=_totals(week), month=_totals(month),
        health=HealthOut(**report.__dict__),
        active_alert=AlertOut.model_validate(open_alert) if open_alert else None,
        trend=trend,
    )
