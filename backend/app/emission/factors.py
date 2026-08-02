"""Vehicle emission factor catalog.

Base CO2 factors (g/km) are representative certified figures for common
Indian vehicle classes (BS6 type-approval range). The speed correction is a
COPERT-shaped curve: emissions per km are highest in stop-go crawling,
minimal near ~60-65 km/h, and rise again at highway speeds.

CO2 from fuel is fixed combustion chemistry:
  petrol: 2310 g CO2 / litre     diesel: 2680 g CO2 / litre
  CNG:    2750 g CO2 / kg (per kg of fuel)
"""
from dataclasses import dataclass

CO2_PER_LITRE = {"petrol": 2310.0, "diesel": 2680.0, "cng": 2750.0}

ENGINE_VERSION = "0.1.0"


@dataclass(frozen=True)
class VehicleClassSpec:
    key: str
    label: str
    fuel: str                # petrol | diesel | cng
    base_ef_gpkm: float      # certified CO2 at type-approval conditions
    engine_litres: float
    idle_g_per_s: float      # CO2 grams per second at idle


# Representative BS6 classes. base_ef figures are mid-range published values.
CATALOG: dict[str, VehicleClassSpec] = {
    spec.key: spec
    for spec in [
        VehicleClassSpec("hatch_petrol", "Hatchback petrol (~1.2L)", "petrol", 115.0, 1.2, 0.55),
        VehicleClassSpec("sedan_petrol", "Sedan petrol (~1.5L)", "petrol", 130.0, 1.5, 0.65),
        VehicleClassSpec("suv_petrol", "SUV petrol (~1.5-2.0L)", "petrol", 160.0, 1.8, 0.80),
        VehicleClassSpec("hatch_diesel", "Hatchback diesel (~1.5L)", "diesel", 105.0, 1.5, 0.50),
        VehicleClassSpec("sedan_diesel", "Sedan diesel (~1.5L)", "diesel", 118.0, 1.5, 0.58),
        VehicleClassSpec("suv_diesel", "SUV diesel (~2.0L)", "diesel", 150.0, 2.0, 0.75),
        VehicleClassSpec("hatch_cng", "Hatchback CNG (~1.2L)", "cng", 95.0, 1.2, 0.45),
    ]
}

DEFAULT_CLASS = "hatch_petrol"

# --- COPERT-shaped speed correction ---------------------------------------
# raw(v) = k1/v + k2 + k3*v^2  (v in km/h), normalised so the curve equals
# 1.0 at the optimum cruise speed. Below ~20 km/h the 1/v term dominates
# (stop-go traffic), above ~90 the v^2 term (aero drag) takes over.
_K1, _K2, _K3, _V_OPT = 22.0, 0.62, 0.000048, 62.0


def _raw(v_kmh: float) -> float:
    v = max(v_kmh, 4.0)  # clamp: below walking pace the idle model applies
    return _K1 / v + _K2 + _K3 * v * v


_RAW_OPT = _raw(_V_OPT)


def speed_multiplier(v_kmh: float) -> float:
    """Multiplier on the base g/km factor for a segment's average speed."""
    return _raw(v_kmh) / _RAW_OPT


def resolve(class_key: str) -> VehicleClassSpec:
    return CATALOG.get(class_key, CATALOG[DEFAULT_CLASS])
