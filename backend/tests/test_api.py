import os
import tempfile
from datetime import datetime, timedelta

os.environ["CARBONTRACE_DB"] = "sqlite:///" + os.path.join(tempfile.gettempdir(), "carbontrace_test.db")

import pytest
from fastapi.testclient import TestClient

from app import database
from app.database import Base, engine
from app.emission.factors import resolve
from app.main import app
from app.simulator import simulate_trip


@pytest.fixture(autouse=True)
def fresh_db():
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    yield


client = TestClient(app)
SPEC = resolve("hatch_petrol")


def make_vehicle() -> int:
    r = client.post("/vehicles", json={
        "name": "Test Swift", "make": "Maruti", "model": "Swift",
        "year": 2021, "class_key": "hatch_petrol",
    })
    assert r.status_code == 200, r.text
    return r.json()["id"]


def upload_sim_trip(vid: int, day: int, degradation: float, seed: int, profile: str = "city"):
    sim = simulate_trip(profile, 18, SPEC, degradation=degradation, seed=seed)
    started = (datetime.utcnow() - timedelta(days=60 - day)).isoformat()
    r = client.post(f"/vehicles/{vid}/trips", json={
        "started_at": started,
        "cold_start": False,
        "fuel_litres": sim.fuel_litres,
        "points": [{"t": p.t, "lat": p.lat, "lon": p.lon, "speed_kmh": p.speed_kmh} for p in sim.points],
    })
    assert r.status_code == 200, r.text
    return r.json()


def test_vehicle_crud_and_catalog():
    assert client.get("/catalog").status_code == 200
    vid = make_vehicle()
    vehicles = client.get("/vehicles").json()
    assert len(vehicles) == 1 and vehicles[0]["id"] == vid


def test_trip_upload_and_scoring():
    vid = make_vehicle()
    trip = upload_sim_trip(vid, 0, 0.0, seed=7)
    assert trip["distance_km"] > 1
    assert trip["co2_g"] > 0
    assert trip["source"] == "fuel"
    assert trip["bucket"] in ("city", "mixed", "highway")


def test_full_degradation_story():
    """The flagship flow: healthy baseline -> degradation -> alert -> serviced -> recovery."""
    vid = make_vehicle()
    for i in range(30):
        upload_sim_trip(vid, i, 0.0, seed=100 + i)

    health = client.get(f"/vehicles/{vid}/health").json()
    assert health["status"] == "ok"

    for i in range(12):
        upload_sim_trip(vid, 30 + i, 0.28, seed=500 + i)

    dash = client.get(f"/vehicles/{vid}/dashboard").json()
    assert dash["health"]["status"] in ("alert", "puc_risk")
    assert dash["active_alert"] is not None
    assert dash["active_alert"]["level"] in ("alert", "puc_risk")

    r = client.post(f"/vehicles/{vid}/serviced")
    assert r.status_code == 200
    assert r.json()["serviced_at"] is not None

    # post-service healthy trips -> recovery alert closes the loop
    for i in range(10):
        upload_sim_trip(vid, 42 + i, 0.0, seed=900 + i)

    alerts = client.get(f"/vehicles/{vid}/alerts").json()
    levels = [a["level"] for a in alerts]
    assert "recovered" in levels
    dash = client.get(f"/vehicles/{vid}/dashboard").json()
    assert dash["active_alert"] is None


def test_fillup_flow_and_calibration():
    """Odometer set once -> trips advance it -> fill-ups give measured
    economy -> vehicle gets calibrated -> health becomes fuel-backed."""
    vid = make_vehicle()
    r = client.post(f"/vehicles/{vid}/odometer", json={"odometer_km": 20000})
    assert r.status_code == 200 and r.json()["odometer_km"] == 20000

    # first fill-up opens the measurement window (odometer auto-filled)
    r = client.post(f"/vehicles/{vid}/fillups", json={
        "litres": 28.0,
        "at": (datetime.utcnow() - timedelta(days=13)).isoformat(),
    })
    assert r.status_code == 200
    assert r.json()["odometer_km"] == 20000

    # drive: model-scored trips advance the virtual odometer
    total_km = 0.0
    for i in range(12):
        sim = simulate_trip("city", 25, SPEC, degradation=0.0, seed=3000 + i)
        started = (datetime.utcnow() - timedelta(days=12 - i)).isoformat()
        rr = client.post(f"/vehicles/{vid}/trips", json={
            "started_at": started, "cold_start": False, "fuel_litres": None,
            "points": [{"t": p.t, "lat": p.lat, "lon": p.lon, "speed_kmh": p.speed_kmh}
                       for p in sim.points],
        })
        assert rr.status_code == 200, rr.text
        total_km += rr.json()["distance_km"]
    veh = [v for v in client.get("/vehicles").json() if v["id"] == vid][0]
    assert abs(veh["odometer_km"] - (20000 + total_km)) < 1.0

    # second full tank closes the window -> measured economy + calibration
    litres = total_km * 7.0 / 100.0  # measured 7 L/100km
    r = client.post(f"/vehicles/{vid}/fillups", json={"litres": round(litres, 2)})
    assert r.status_code == 200
    eco = client.get(f"/vehicles/{vid}/economy").json()
    assert eco["fillups"] == 2
    assert len(eco["segments"]) == 1
    assert abs(eco["segments"][0]["l_per_100km"] - 7.0) < 0.15
    assert eco["calibration_factor"] != 1.0
    assert eco["calibrated_at"] is not None

    health = client.get(f"/vehicles/{vid}/health").json()
    assert health["fuel_backed"] or health["status"] == "learning"


def test_connected_mock_sync():
    vid = make_vehicle()
    client.post(f"/vehicles/{vid}/odometer", json={"odometer_km": 5000})
    r = client.post(f"/vehicles/{vid}/connected/sync")
    assert r.status_code == 200
    f = r.json()
    assert f["source"] == "connected"
    assert f["odometer_km"] > 5000
    assert f["litres"] > 0


def test_dashboard_totals_shape():
    vid = make_vehicle()
    upload_sim_trip(vid, 59, 0.0, seed=42)  # today-ish
    dash = client.get(f"/vehicles/{vid}/dashboard").json()
    assert dash["month"]["trips"] >= 1
    assert dash["month"]["co2_kg"] > 0
    assert isinstance(dash["trend"], list) and dash["trend"]
