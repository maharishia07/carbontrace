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

    model_config = {"from_attributes": True}


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
