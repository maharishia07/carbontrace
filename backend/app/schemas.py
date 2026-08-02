from datetime import datetime

from pydantic import BaseModel, Field


class GpsPointIn(BaseModel):
    t: float = Field(description="unix seconds")
    lat: float
    lon: float
    speed_kmh: float | None = None


class TripIn(BaseModel):
    started_at: datetime
    points: list[GpsPointIn]
    cold_start: bool = False
    fuel_litres: float | None = Field(default=None, description="actual fuel used, if known")


class VehicleIn(BaseModel):
    name: str
    make: str = ""
    model: str = ""
    year: int = 2020
    class_key: str = "hatch_petrol"
    puc_expiry: datetime | None = None


class VehicleOut(VehicleIn):
    id: int
    created_at: datetime
    calibration_factor: float = 1.0
    calibrated_at: datetime | None = None
    odometer_km: float = 0.0

    model_config = {"from_attributes": True}


class OdometerIn(BaseModel):
    odometer_km: float = Field(gt=0, description="current dashboard odometer reading")


class FillUpIn(BaseModel):
    litres: float = Field(gt=0)
    odometer_km: float | None = Field(default=None, description="omit to use the virtual odometer")
    full_tank: bool = True
    at: datetime | None = None


class FillUpOut(BaseModel):
    id: int
    vehicle_id: int
    at: datetime
    odometer_km: float
    litres: float
    full_tank: bool
    source: str

    model_config = {"from_attributes": True}


class EconomySegmentOut(BaseModel):
    start_at: datetime
    end_at: datetime
    km: float
    litres: float
    l_per_100km: float
    measured_gpkm: float
    modeled_gpkm: float | None
    calibration: float | None


class EconomyOut(BaseModel):
    segments: list[EconomySegmentOut]
    calibration_factor: float
    calibrated_at: datetime | None
    fillups: int


class TripOut(BaseModel):
    id: int
    vehicle_id: int
    started_at: datetime
    ended_at: datetime
    distance_km: float
    duration_s: float
    idle_s: float
    avg_moving_speed_kmh: float
    co2_g: float
    gpkm: float
    idle_co2_g: float
    harsh_events: int
    cold_start: bool
    refuel_stop: bool = False
    bucket: str
    eco_score: int
    source: str
    engine_version: str

    model_config = {"from_attributes": True}


class AlertOut(BaseModel):
    id: int
    vehicle_id: int
    created_at: datetime
    level: str
    drift_pct: float
    message: str
    resolved: bool
    serviced_at: datetime | None

    model_config = {"from_attributes": True}


class HealthOut(BaseModel):
    status: str
    drift_pct: float
    ewma: float
    trips_analyzed: int
    baselines: dict[str, float]
    sustained: int
    idle_rising: bool
    fuel_backed: bool
    message: str


class PeriodTotals(BaseModel):
    trips: int
    distance_km: float
    co2_kg: float
    avg_gpkm: float | None


class DashboardOut(BaseModel):
    vehicle: VehicleOut
    today: PeriodTotals
    week: PeriodTotals
    month: PeriodTotals
    health: HealthOut
    active_alert: AlertOut | None
    trend: list[dict]  # [{date, gpkm, bucket}] most recent 60 trips
    # set when a recent trip contained a fuel-station-like stop and no
    # fill-up has been logged since — the app prompts with odometer ready
    refuel_hint_at: datetime | None = None
