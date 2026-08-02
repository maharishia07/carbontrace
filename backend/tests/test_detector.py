from app.anomaly.detector import TripSample, analyze


def mk(gpkm: float, bucket: str = "city", idle_rate: float = 0.55, source: str = "fuel") -> TripSample:
    return TripSample(gpkm=gpkm, bucket=bucket, idle_g_per_s=idle_rate, source=source)


def healthy_history(n: int = 30) -> list[TripSample]:
    # ~150 g/km city with mild noise
    return [mk(150.0 + (i % 5) * 2.0 - 4.0) for i in range(n)]


def test_learning_with_few_trips():
    report = analyze([mk(150.0) for _ in range(4)])
    assert report.status == "learning"


def test_healthy_is_ok():
    report = analyze(healthy_history())
    assert report.status == "ok"
    assert abs(report.drift_pct) < 5


def test_sustained_degradation_alerts():
    history = healthy_history(30)
    degraded = [mk(150.0 * 1.25, idle_rate=0.55) for _ in range(12)]
    report = analyze(history + degraded)
    assert report.status in ("alert", "puc_risk")
    assert report.drift_pct > 15
    assert report.sustained >= 5
    assert report.fuel_backed


def test_puc_risk_needs_idle_rise():
    history = healthy_history(30)
    degraded = [mk(150.0 * 1.32, idle_rate=0.75) for _ in range(12)]
    report = analyze(history + degraded)
    assert report.status == "puc_risk"
    assert report.idle_rising


def test_single_bad_trip_does_not_alert():
    history = healthy_history(30)
    report = analyze(history + [mk(150.0 * 1.4)])
    assert report.status in ("ok", "watch")


def test_traffic_week_not_a_fault():
    """City trips vs highway trips have different baselines — a week of
    city-only driving must not read as degradation."""
    history = [mk(150.0, "city") for _ in range(15)] + [mk(95.0, "highway") for _ in range(15)]
    city_week = [mk(151.0, "city") for _ in range(7)]
    report = analyze(history + city_week)
    assert report.status == "ok"


def test_model_only_alert_is_flagged_not_fuel_backed():
    history = [mk(150.0, source="model") for _ in range(30)]
    degraded = [mk(150.0 * 1.25, source="model") for _ in range(12)]
    report = analyze(history + degraded)
    assert not report.fuel_backed
    if report.status in ("alert", "puc_risk"):
        assert "fuel data" in report.message
