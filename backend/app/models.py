from datetime import datetime, timezone

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Vehicle(Base):
    __tablename__ = "vehicles"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(80))
    make: Mapped[str] = mapped_column(String(60), default="")
    model: Mapped[str] = mapped_column(String(60), default="")
    year: Mapped[int] = mapped_column(Integer, default=2020)
    class_key: Mapped[str] = mapped_column(String(40))
    puc_expiry: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)

    trips: Mapped[list["Trip"]] = relationship(back_populates="vehicle", cascade="all, delete-orphan")
    alerts: Mapped[list["Alert"]] = relationship(back_populates="vehicle", cascade="all, delete-orphan")


class Trip(Base):
    __tablename__ = "trips"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    vehicle_id: Mapped[int] = mapped_column(ForeignKey("vehicles.id"), index=True)
    started_at: Mapped[datetime] = mapped_column(DateTime, index=True)
    ended_at: Mapped[datetime] = mapped_column(DateTime)
    distance_km: Mapped[float] = mapped_column(Float)
    duration_s: Mapped[float] = mapped_column(Float)
    idle_s: Mapped[float] = mapped_column(Float)
    avg_moving_speed_kmh: Mapped[float] = mapped_column(Float)
    co2_g: Mapped[float] = mapped_column(Float)
    gpkm: Mapped[float] = mapped_column(Float)
    idle_co2_g: Mapped[float] = mapped_column(Float, default=0.0)
    harsh_events: Mapped[int] = mapped_column(Integer, default=0)
    cold_start: Mapped[bool] = mapped_column(Boolean, default=False)
    bucket: Mapped[str] = mapped_column(String(10))
    eco_score: Mapped[int] = mapped_column(Integer)
    source: Mapped[str] = mapped_column(String(10), default="model")
    fuel_litres: Mapped[float | None] = mapped_column(Float, nullable=True)
    engine_version: Mapped[str] = mapped_column(String(12))

    vehicle: Mapped[Vehicle] = relationship(back_populates="trips")


class Alert(Base):
    __tablename__ = "alerts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    vehicle_id: Mapped[int] = mapped_column(ForeignKey("vehicles.id"), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
    level: Mapped[str] = mapped_column(String(12))       # watch | alert | puc_risk | recovered
    drift_pct: Mapped[float] = mapped_column(Float)
    message: Mapped[str] = mapped_column(String(500))
    resolved: Mapped[bool] = mapped_column(Boolean, default=False)
    serviced_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    vehicle: Mapped[Vehicle] = relationship(back_populates="alerts")
