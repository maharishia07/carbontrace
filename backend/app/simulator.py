"""Synthetic trip generator.

Produces realistic GPS traces (1 point per 3 s) for city / mixed / highway
drives, and can simulate a degrading engine by inflating the actual fuel
consumed (which is how degradation manifests in the real world: same drive,
more fuel). Deterministic via seed so demos are reproducible.
"""
import random
from dataclasses import dataclass

from .emission.engine import GpsPoint
from .emission.factors import CO2_PER_LITRE, VehicleClassSpec

BASE_LAT, BASE_LON = 13.0827, 80.2707  # Chennai
KM_PER_DEG_LAT = 110.574


@dataclass
class SimTrip:
    points: list[GpsPoint]
    fuel_litres: float
    profile: str


# target speed bands per profile: (cruise_kmh, stop_probability_per_min)
PROFILES = {
    "city": (24.0, 0.55),
    "mixed": (45.0, 0.25),
    "highway": (75.0, 0.05),
}


def simulate_trip(
    profile: str,
    duration_min: float,
    spec: VehicleClassSpec,
    degradation: float = 0.0,   # 0.0 healthy, 0.22 = engine burns +22% fuel
    seed: int = 0,
    t0: float = 1_700_000_000.0,
) -> SimTrip:
    rng = random.Random(seed)
    cruise, stop_p = PROFILES[profile]
    dt = 3.0
    steps = int(duration_min * 60 / dt)

    points: list[GpsPoint] = []
    lat, lon = BASE_LAT + rng.uniform(-0.05, 0.05), BASE_LON + rng.uniform(-0.05, 0.05)
    v = 0.0
    stopped_for = 0
    heading_lat = rng.choice([-1, 1])

    for i in range(steps):
        t = t0 + i * dt
        if stopped_for > 0:
            stopped_for -= 1
            v = 0.0
        else:
            if rng.random() < stop_p * dt / 60.0:
                stopped_for = rng.randint(4, 25)   # 12-75 s stop (signal/traffic)
                v = 0.0
            else:
                target = cruise * rng.uniform(0.75, 1.2)
                v += max(-14.0, min(9.0, target - v)) * rng.uniform(0.3, 0.7)
                v = max(0.0, v)
        dist_km = v * dt / 3600.0
        lat += heading_lat * dist_km / KM_PER_DEG_LAT
        points.append(GpsPoint(t=t, lat=lat, lon=lon, speed_kmh=round(v, 1)))

    total_km = sum(p.speed_kmh * dt / 3600.0 for p in points)
    # healthy fuel burn from the vehicle's certified factor, worsened in
    # stop-go traffic, plus the degradation factor
    profile_penalty = {"city": 1.25, "mixed": 1.05, "highway": 1.0}[profile]
    healthy_g = total_km * spec.base_ef_gpkm * profile_penalty
    litres = healthy_g / CO2_PER_LITRE[spec.fuel] * (1.0 + degradation) * rng.uniform(0.96, 1.04)

    return SimTrip(points=points, fuel_litres=round(litres, 3), profile=profile)
