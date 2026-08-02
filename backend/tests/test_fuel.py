from datetime import datetime, timedelta

from app.emission.factors import CO2_PER_LITRE
from app.fuel import economy_segments, update_calibration
from app.models import FillUp, Trip, Vehicle


def vehicle() -> Vehicle:
    return Vehicle(id=1, name="T", class_key="hatch_petrol", calibration_factor=1.0)


def fillup(day: int, odo: float, litres: float, full: bool = True) -> FillUp:
    return FillUp(vehicle_id=1, at=datetime(2026, 7, 1) + timedelta(days=day),
                  odometer_km=odo, litres=litres, full_tank=full)


def trip(day: int, km: float, gpkm: float) -> Trip:
    t = Trip(vehicle_id=1, started_at=datetime(2026, 7, 1) + timedelta(days=day, hours=9),
             ended_at=datetime(2026, 7, 1) + timedelta(days=day, hours=10),
             distance_km=km, duration_s=3600, idle_s=0, avg_moving_speed_kmh=30,
             co2_g=km * gpkm, gpkm=gpkm, idle_co2_g=0, harsh_events=0,
             cold_start=False, bucket="city", eco_score=80, source="model",
             engine_version="0.1.0")
    return t


def test_tank_to_tank_economy():
    v = vehicle()
    # 400 km on 26 litres of petrol
    fills = [fillup(0, 10000, 30), fillup(10, 10400, 26)]
    segs = economy_segments(v, fills, [])
    assert len(segs) == 1
    s = segs[0]
    assert s.km == 400
    assert abs(s.l_per_100km - 6.5) < 0.01
    expected_gpkm = 26 * CO2_PER_LITRE["petrol"] / 400
    assert abs(s.measured_gpkm - expected_gpkm) < 0.5


def test_partial_tank_ignored():
    v = vehicle()
    fills = [fillup(0, 10000, 30), fillup(5, 10200, 12, full=False), fillup(10, 10400, 26)]
    segs = economy_segments(v, fills, [])
    # partial fill breaks nothing: one full-to-full segment
    assert len(segs) == 1
    assert segs[0].km == 400


def test_calibration_from_trips():
    v = vehicle()
    # model says 125 g/km over the window; measured says ~150 -> k ~= 1.2
    trips = [trip(d, 40, 125.0) for d in range(1, 10)]  # 360 km modeled
    measured_litres = 400 * 150.0 / CO2_PER_LITRE["petrol"]
    fills = [fillup(0, 10000, 30), fillup(10, 10400, measured_litres)]
    segs = economy_segments(v, fills, trips)
    assert segs[0].calibration is not None
    assert 1.15 < segs[0].calibration < 1.25
    k = update_calibration(v, segs)
    assert 1.05 < k < 1.25  # EWMA from 1.0 toward ~1.2
    assert v.calibrated_at is not None


def test_short_segment_rejected():
    v = vehicle()
    fills = [fillup(0, 10000, 30), fillup(1, 10020, 1.5)]  # 20 km — too noisy
    assert economy_segments(v, fills, []) == []
