import pytest

from app.emission.engine import GpsPoint, score_trip
from app.emission.factors import CO2_PER_LITRE, resolve, speed_multiplier

SPEC = resolve("hatch_petrol")


def steady_trace(speed_kmh: float, minutes: float, dt: float = 3.0) -> list[GpsPoint]:
    """Straight-line trace at constant speed."""
    pts = []
    lat = 13.0
    km_per_step = speed_kmh * dt / 3600.0
    for i in range(int(minutes * 60 / dt)):
        pts.append(GpsPoint(t=i * dt, lat=lat, lon=80.0, speed_kmh=speed_kmh))
        lat += km_per_step / 110.574
    return pts


def test_steady_cruise_near_base_factor():
    r = score_trip(steady_trace(62.0, 20), SPEC)
    assert r.source == "model"
    assert r.distance_km == pytest.approx(62.0 * 20 / 60, rel=0.02)
    # at optimum speed the multiplier is 1.0 -> g/km close to certified base
    assert r.gpkm == pytest.approx(SPEC.base_ef_gpkm, rel=0.05)
    assert r.bucket == "highway"


def test_city_dirtier_than_cruise_per_km():
    city = score_trip(steady_trace(18.0, 30), SPEC)
    cruise = score_trip(steady_trace(62.0, 30), SPEC)
    assert city.gpkm > cruise.gpkm * 1.3
    assert city.bucket == "city"


def test_speed_curve_shape():
    assert speed_multiplier(10) > speed_multiplier(30) > speed_multiplier(62)
    assert speed_multiplier(110) > speed_multiplier(62)


def test_idle_counted():
    pts = steady_trace(40.0, 10)
    t0 = pts[-1].t
    lat, lon = pts[-1].lat, pts[-1].lon
    for i in range(1, 101):  # 5 minutes stationary
        pts.append(GpsPoint(t=t0 + i * 3.0, lat=lat, lon=lon, speed_kmh=0.0))
    r = score_trip(pts, SPEC)
    assert r.idle_s == pytest.approx(300.0, abs=6.0)
    assert r.idle_co2_g == pytest.approx(300.0 * SPEC.idle_g_per_s, rel=0.05)


def test_cold_start_adds_emissions():
    warm = score_trip(steady_trace(40.0, 15), SPEC, cold_start=False)
    cold = score_trip(steady_trace(40.0, 15), SPEC, cold_start=True)
    assert cold.co2_g > warm.co2_g
    assert cold.cold_start_extra_g > 0


def test_fuel_path_is_chemistry():
    r = score_trip(steady_trace(50.0, 20), SPEC, fuel_litres=1.2)
    assert r.source == "fuel"
    expected = 1.2 * CO2_PER_LITRE["petrol"]
    # fuel CO2 plus idle/harsh components; steady trace has neither
    assert r.co2_g == pytest.approx(expected, rel=0.01)


def test_too_short_trip_rejected():
    with pytest.raises(ValueError):
        score_trip(steady_trace(5.0, 0.5), SPEC)


def test_eco_score_bounds():
    r = score_trip(steady_trace(62.0, 20), SPEC)
    assert 0 <= r.eco_score <= 100
    assert r.eco_score >= 85  # clean steady cruise should score high
