"""Measured fuel economy and model calibration.

Fill-ups are the measured ground truth. Between consecutive FULL-TANK
fill-ups, the litres added at the later one = fuel burned across the
odometer distance. From that:

  measured L/100km, measured g CO2/km (litres x combustion factor / km)

Calibration: over the same window we sum what the MODEL said the trips
emitted. The ratio measured/modeled becomes the vehicle's calibration
factor (EWMA-smoothed, clamped) — after 2-3 fill-ups every trip figure is
anchored to real fuel, and drift detection runs on measured reality, not
on an open-loop model.
"""
from dataclasses import dataclass
from datetime import datetime

from .emission.factors import CO2_PER_LITRE, resolve
from .models import FillUp, Trip, Vehicle

CALIBRATION_EWMA = 0.5          # weight of the newest segment
CALIBRATION_CLAMP = (0.5, 2.0)  # sanity bounds on measured/modeled
MIN_SEGMENT_KM = 40.0           # shorter segments are too noisy to trust


@dataclass
class EconomySegment:
    start_at: datetime
    end_at: datetime
    km: float
    litres: float
    l_per_100km: float
    measured_gpkm: float
    modeled_gpkm: float | None   # model average over same window, if trips exist
    calibration: float | None    # measured / modeled


def economy_segments(vehicle: Vehicle, fillups: list[FillUp], trips: list[Trip]) -> list[EconomySegment]:
    """fillups and trips must be in chronological order."""
    spec = resolve(vehicle.class_key)
    co2_per_l = CO2_PER_LITRE[spec.fuel]
    full = [f for f in fillups if f.full_tank]
    segments: list[EconomySegment] = []

    for a, b in zip(full, full[1:]):
        km = b.odometer_km - a.odometer_km
        if km < MIN_SEGMENT_KM or b.litres <= 0:
            continue
        measured_gpkm = b.litres * co2_per_l / km

        window = [t for t in trips if a.at <= t.started_at <= b.at and t.source == "model"]
        modeled_gpkm = None
        calibration = None
        w_km = sum(t.distance_km for t in window)
        if w_km >= km * 0.3:  # trips cover enough of the segment to compare
            modeled_gpkm = sum(t.co2_g for t in window) / w_km
            if modeled_gpkm > 0:
                calibration = measured_gpkm / modeled_gpkm

        segments.append(EconomySegment(
            start_at=a.at, end_at=b.at, km=round(km, 1), litres=round(b.litres, 2),
            l_per_100km=round(b.litres / km * 100.0, 2),
            measured_gpkm=round(measured_gpkm, 1),
            modeled_gpkm=round(modeled_gpkm, 1) if modeled_gpkm else None,
            calibration=round(calibration, 3) if calibration else None,
        ))
    return segments


def update_calibration(vehicle: Vehicle, segments: list[EconomySegment]) -> float:
    """Fold segment calibrations into the vehicle's smoothed factor."""
    k = vehicle.calibration_factor or 1.0
    lo, hi = CALIBRATION_CLAMP
    updated = False
    for seg in segments:
        if seg.calibration is None:
            continue
        c = min(hi, max(lo, seg.calibration))
        k = CALIBRATION_EWMA * c + (1 - CALIBRATION_EWMA) * k
        updated = True
    if updated:
        vehicle.calibration_factor = round(k, 4)
        vehicle.calibrated_at = segments[-1].end_at
    return vehicle.calibration_factor
