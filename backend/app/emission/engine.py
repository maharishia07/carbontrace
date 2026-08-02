"""Trip emission engine.

Scores a GPS trace (sequence of timestamped points) into a CO2 estimate.

Two paths:
  1. Model path (always available): COPERT-shaped speed-dependent factor per
     moving segment + idle emissions + cold-start and harsh-acceleration
     penalties.
  2. Fuel path (when actual fuel consumed is known, e.g. from a connected-car
     API or a fill-up log): CO2 = litres x combustion factor. Chemistry, not
     modelling — this path also makes engine-degradation drift observable.
"""
from dataclasses import dataclass, field
from math import asin, cos, radians, sin, sqrt

from .factors import CO2_PER_LITRE, ENGINE_VERSION, VehicleClassSpec, speed_multiplier

IDLE_SPEED_KMH = 2.0          # below this the car is considered stationary
HARSH_ACCEL_MS2 = 2.5         # threshold for a harsh-acceleration event
HARSH_EVENT_G_PER_L = 4.0     # extra CO2 grams per event per litre displacement
COLD_START_KM = 2.5           # distance over which a cold engine runs rich
COLD_START_EXTRA = 0.35       # +35% emissions over that distance
MIN_TRIP_KM = 0.2
CITY_MAX_KMH = 30.0           # avg moving speed buckets
MIXED_MAX_KMH = 55.0


@dataclass
class GpsPoint:
    t: float      # unix seconds
    lat: float
    lon: float
    speed_kmh: float | None = None  # optional; derived from positions if absent


@dataclass
class TripResult:
    distance_km: float
    duration_s: float
    idle_s: float
    moving_s: float
    avg_moving_speed_kmh: float
    co2_g: float
    gpkm: float
    idle_co2_g: float
    cold_start_extra_g: float
    harsh_events: int
    harsh_extra_g: float
    bucket: str                  # city | mixed | highway
    eco_score: int               # 0-100
    source: str                  # model | fuel
    engine_version: str = ENGINE_VERSION
    warnings: list[str] = field(default_factory=list)


def haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    lat1, lon1, lat2, lon2 = map(radians, (lat1, lon1, lat2, lon2))
    dlat, dlon = lat2 - lat1, lon2 - lon1
    a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    return 2 * 6371.0088 * asin(sqrt(a))


def _prepare(points: list[GpsPoint]) -> list[tuple[float, float, float]]:
    """Return per-interval (dt_s, dist_km, speed_kmh) between consecutive points."""
    out = []
    for a, b in zip(points, points[1:]):
        dt = b.t - a.t
        if dt <= 0:
            continue
        if dt > 120:  # GPS gap — distance unknown, skip interval
            continue
        dist = haversine_km(a.lat, a.lon, b.lat, b.lon)
        v = b.speed_kmh if b.speed_kmh is not None else (dist / dt) * 3600.0
        # implausible jump filter (>160 km/h between samples on Indian roads)
        if v > 180.0:
            continue
        out.append((dt, dist, v))
    return out


def score_trip(
    points: list[GpsPoint],
    spec: VehicleClassSpec,
    cold_start: bool = False,
    fuel_litres: float | None = None,
) -> TripResult:
    """Score one trip. Raises ValueError for traces too short to score."""
    if len(points) < 2:
        raise ValueError("trip needs at least 2 GPS points")

    intervals = _prepare(points)
    if not intervals:
        raise ValueError("no usable GPS intervals in trace")

    duration = sum(dt for dt, _, _ in intervals)
    distance = sum(d for _, d, _ in intervals)
    if distance < MIN_TRIP_KM:
        raise ValueError(f"trip too short to score ({distance:.2f} km)")

    idle_s = sum(dt for dt, _, v in intervals if v < IDLE_SPEED_KMH)
    moving = [(dt, d, v) for dt, d, v in intervals if v >= IDLE_SPEED_KMH]
    moving_s = sum(dt for dt, _, _ in moving)
    moving_km = sum(d for _, d, _ in moving)
    avg_moving = (moving_km / moving_s * 3600.0) if moving_s > 0 else 0.0

    # harsh acceleration events from speed deltas
    harsh = 0
    prev_v = None
    for dt, _, v in intervals:
        if prev_v is not None and dt > 0:
            accel = (v - prev_v) / 3.6 / dt  # m/s^2
            if accel > HARSH_ACCEL_MS2:
                harsh += 1
        prev_v = v

    warnings: list[str] = []

    # --- CO2 ---------------------------------------------------------------
    idle_g = idle_s * spec.idle_g_per_s
    harsh_g = harsh * HARSH_EVENT_G_PER_L * spec.engine_litres

    if fuel_litres is not None and fuel_litres > 0:
        co2 = fuel_litres * CO2_PER_LITRE[spec.fuel]
        source = "fuel"
        cold_g = 0.0  # already contained in real fuel burned
    else:
        moving_g = sum(d * spec.base_ef_gpkm * speed_multiplier(v) for _, d, v in moving)
        cold_g = 0.0
        if cold_start:
            cold_km = min(COLD_START_KM, distance)
            cold_g = cold_km * spec.base_ef_gpkm * COLD_START_EXTRA
        co2 = moving_g + idle_g + cold_g + harsh_g
        source = "model"
        warnings.append("model estimate (+/-15%); link fuel data for higher accuracy")

    gpkm = co2 / distance

    bucket = (
        "city" if avg_moving < CITY_MAX_KMH
        else "mixed" if avg_moving < MIXED_MAX_KMH
        else "highway"
    )

    # --- eco score ----------------------------------------------------------
    # start at 100; penalise g/km vs certified base, idle share, harsh events
    ratio = gpkm / spec.base_ef_gpkm
    idle_share = idle_s / duration if duration else 0.0
    score = 100.0
    score -= max(0.0, (ratio - 1.0)) * 100.0          # 1% over base = -1
    score -= idle_share * 40.0                          # 25% idling = -10
    score -= min(harsh, 20) * 1.5
    eco = int(max(0, min(100, round(score))))

    return TripResult(
        distance_km=round(distance, 3),
        duration_s=round(duration, 1),
        idle_s=round(idle_s, 1),
        moving_s=round(moving_s, 1),
        avg_moving_speed_kmh=round(avg_moving, 1),
        co2_g=round(co2, 1),
        gpkm=round(gpkm, 2),
        idle_co2_g=round(idle_g, 1),
        cold_start_extra_g=round(cold_g, 1),
        harsh_events=harsh,
        harsh_extra_g=round(harsh_g, 1),
        bucket=bucket,
        eco_score=eco,
        source=source,
        warnings=warnings,
    )
