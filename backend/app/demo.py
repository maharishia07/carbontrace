"""Seed a demo vehicle with a healthy -> degraded trip history.

Run:  python -m app.demo
Then open http://127.0.0.1:8000/docs and call /vehicles/1/dashboard.
"""
from datetime import datetime, timedelta

from .database import SessionLocal, init_db
from .emission.factors import resolve
from .main import _refresh_health
from .models import Trip, Vehicle
from .simulator import simulate_trip
from .emission.engine import score_trip


def seed(healthy: int = 40, degraded: int = 15) -> None:
    init_db()
    db = SessionLocal()
    try:
        vehicle = Vehicle(
            name="Demo Swift", make="Maruti", model="Swift VXI", year=2021,
            class_key="hatch_petrol",
        )
        db.add(vehicle)
        db.commit()
        spec = resolve(vehicle.class_key)

        start = datetime.utcnow() - timedelta(days=healthy + degraded)
        profiles = ["city", "city", "mixed", "city", "highway", "mixed", "city"]

        for i in range(healthy + degraded):
            degradation = 0.0 if i < healthy else 0.30
            profile = profiles[i % len(profiles)]
            sim = simulate_trip(
                profile, duration_min=18 if profile == "city" else 30,
                spec=spec, degradation=degradation, seed=1000 + i,
            )
            r = score_trip(sim.points, spec, cold_start=(i % 3 == 0), fuel_litres=sim.fuel_litres)
            started = start + timedelta(days=i, hours=9)
            db.add(Trip(
                vehicle_id=vehicle.id, started_at=started,
                ended_at=started + timedelta(seconds=r.duration_s),
                distance_km=r.distance_km, duration_s=r.duration_s, idle_s=r.idle_s,
                avg_moving_speed_kmh=r.avg_moving_speed_kmh, co2_g=r.co2_g,
                gpkm=r.gpkm, idle_co2_g=r.idle_co2_g, harsh_events=r.harsh_events,
                cold_start=(i % 3 == 0), bucket=r.bucket, eco_score=r.eco_score,
                source=r.source, fuel_litres=sim.fuel_litres,
                engine_version=r.engine_version,
            ))
            db.commit()

        report = _refresh_health(db, vehicle)
        print(f"Seeded vehicle #{vehicle.id} '{vehicle.name}' with {healthy} healthy + {degraded} degraded trips")
        print(f"Health: {report.status}  drift {report.drift_pct:+.1f}%  ({report.message})")
    finally:
        db.close()


if __name__ == "__main__":
    seed()
