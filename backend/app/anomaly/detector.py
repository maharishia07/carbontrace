"""Per-vehicle emission-drift detection.

Approach: every scored trip contributes a g/km value tagged with a speed
bucket (city / mixed / highway). Each bucket keeps a robust baseline
(median + MAD) learned from the vehicle's own early history; new trips are
normalised against their bucket's baseline so a week of heavy traffic does
not masquerade as an engine fault. An EWMA control chart (lambda = 0.2)
over the normalised ratios detects sustained drift.

Thresholds (relative to the car's own baseline):
  watch    : EWMA > +10%
  alert    : EWMA > +20% AND at least 5 of the last 7 trips > +15%
  puc_risk : EWMA > +25% AND idle-phase emissions also rising

Degradation is only physically observable when trips carry real fuel data
(source == "fuel"); on pure model estimates the detector reports behaviour
drift only, and the API surfaces that honestly.
"""
from dataclasses import dataclass
from statistics import median

EWMA_LAMBDA = 0.2
BASELINE_MIN_TRIPS = 8      # per bucket before that bucket is trusted
BASELINE_WINDOW = 30        # trips used to (re)build a bucket baseline
WATCH_DRIFT = 0.10
ALERT_DRIFT = 0.20
PUC_DRIFT = 0.25
SUSTAIN_OVER = 0.15
SUSTAIN_WINDOW = 7
SUSTAIN_MIN = 5
RECOVERY_BAND = 0.05        # back within +5% of baseline = recovered


@dataclass
class TripSample:
    gpkm: float
    bucket: str              # city | mixed | highway
    idle_g_per_s: float      # observed idle CO2 rate for the trip (idle_co2_g / idle_s)
    source: str              # model | fuel


@dataclass
class HealthReport:
    status: str              # learning | ok | watch | alert | puc_risk
    drift_pct: float         # EWMA drift over baseline, in percent
    ewma: float              # EWMA of normalised ratios (1.0 == baseline)
    trips_analyzed: int
    baselines: dict          # bucket -> baseline g/km
    sustained: int           # trips over +15% in the last 7
    idle_rising: bool
    fuel_backed: bool        # detection based on real fuel data
    message: str


def _bucket_baselines(samples: list[TripSample]) -> dict[str, float]:
    """Robust per-bucket baseline from the earliest BASELINE_WINDOW trips."""
    out: dict[str, float] = {}
    for bucket in ("city", "mixed", "highway"):
        vals = [s.gpkm for s in samples if s.bucket == bucket][:BASELINE_WINDOW]
        if len(vals) >= BASELINE_MIN_TRIPS:
            out[bucket] = median(vals)
    return out


def analyze(samples: list[TripSample]) -> HealthReport:
    """samples must be in chronological order."""
    n = len(samples)
    baselines = _bucket_baselines(samples)

    if not baselines:
        return HealthReport(
            status="learning", drift_pct=0.0, ewma=1.0, trips_analyzed=n,
            baselines={}, sustained=0, idle_rising=False,
            fuel_backed=False,
            message=f"Building your car's baseline — {n} trips recorded, "
                    f"insights unlock after ~{BASELINE_MIN_TRIPS} trips per driving type.",
        )

    # normalised ratios for trips whose bucket has a baseline
    ratios = [
        (s.gpkm / baselines[s.bucket], s)
        for s in samples
        if s.bucket in baselines
    ]
    if not ratios:
        return HealthReport(
            status="learning", drift_pct=0.0, ewma=1.0, trips_analyzed=n,
            baselines=baselines, sustained=0, idle_rising=False,
            fuel_backed=False, message="Baseline learning in progress.",
        )

    ewma = 1.0
    for r, _ in ratios:
        ewma = EWMA_LAMBDA * r + (1 - EWMA_LAMBDA) * ewma

    recent = ratios[-SUSTAIN_WINDOW:]
    sustained = sum(1 for r, _ in recent if r > 1 + SUSTAIN_OVER)

    # idle-phase trend: recent window vs baseline period
    early_idle = [s.idle_g_per_s for _, s in ratios[:BASELINE_WINDOW] if s.idle_g_per_s > 0]
    recent_idle = [s.idle_g_per_s for _, s in recent if s.idle_g_per_s > 0]
    idle_rising = bool(
        early_idle and recent_idle
        and median(recent_idle) > median(early_idle) * (1 + WATCH_DRIFT)
    )

    # is the recent signal grounded in real fuel data? ("fuel" = direct fuel
    # figures; "calibrated" = model trips anchored by fill-up measurements)
    fuel_backed = sum(
        1 for _, s in recent if s.source in ("fuel", "calibrated")
    ) >= max(1, len(recent) // 2)

    drift = ewma - 1.0
    drift_pct = round(drift * 100.0, 1)

    if drift > PUC_DRIFT and sustained >= SUSTAIN_MIN and idle_rising:
        status = "puc_risk"
        message = (f"Emissions are ~{drift_pct:.0f}% above your baseline and idle emissions "
                   f"are rising — high risk of failing the next PUC test. Service recommended now.")
    elif drift > ALERT_DRIFT and sustained >= SUSTAIN_MIN:
        status = "alert"
        message = (f"CO2 per km has been ~{drift_pct:.0f}% above your baseline across "
                   f"{sustained} of your last {len(recent)} trips. Likely causes: air filter, "
                   f"spark plugs, O2 sensor, injectors. Service recommended.")
    elif drift > WATCH_DRIFT:
        status = "watch"
        message = (f"Emissions are trending ~{drift_pct:.0f}% above your baseline. "
                   f"Watching — no action needed yet.")
    else:
        status = "ok"
        message = "Emissions are within your car's normal range."

    if status in ("alert", "puc_risk") and not fuel_backed:
        message += (" Note: this signal is based on driving-pattern estimates; "
                    "link fuel data (connected car or fill-up log) to confirm engine health.")

    return HealthReport(
        status=status, drift_pct=drift_pct, ewma=round(ewma, 4), trips_analyzed=n,
        baselines={k: round(v, 2) for k, v in baselines.items()},
        sustained=sustained, idle_rising=idle_rising, fuel_backed=fuel_backed,
        message=message,
    )
