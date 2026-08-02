# CarbonTrace — Execution Plan
### A fully software-based vehicle carbon emission monitor
*Real-world execution blueprint, structured to also win hackathons.*

---

## 1. Vision & Positioning

**One-liner:** Every car owner should know their car's emissions the way they know their phone's battery percentage — continuously, automatically, and free of hardware.

**Positioning statement:** CarbonTrace is not a measurement device and never claims to be. It is a *continuous emission intelligence layer* built from data the car and phone already produce. The product promise is: **"Know before you pollute. Service before you fail."**

Three customer wedges, in order of attack:
1. **Individual car owners (B2C)** — emission awareness + service alerts + PUC-failure prediction.
2. **MSME fleets (B2B)** — 5–50 vehicle businesses (delivery, cabs, distributors) get a fleet emission dashboard, per-vehicle health flags, and audit-ready CO₂ reports for green-compliance tenders.
3. **Service ecosystem (B2B2C)** — garages and service chains receive qualified "this car needs service" leads.

---

## 2. System Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌───────────────────┐    ┌──────────────────┐
│  DATA SOURCES   │    │    MOBILE APP     │    │   CLOUD BACKEND   │    │     INSIGHTS     │
│                 │    │                  │    │                   │    │                  │
│ Car Bluetooth   │──▶│ Trip Detection    │──▶│ Emission Engine    │──▶│ Trip CO₂ records │
│ (ignition sig.) │    │ Service (native) │    │ (COPERT/BS6 + VSP)│    │ g/km trend chart │
│                 │    │                  │    │                   │    │                  │
│ GPS + IMU       │──▶│ Trip Recorder     │──▶│ Baseline Engine    │──▶│ Health score     │
│ (drive profile) │    │ (adaptive sample)│    │ (per-car, per-    │    │ Service alerts   │
│                 │    │                  │    │  speed-bucket)    │    │                  │
│ Connected-car   │──▶│ Local store       │──▶│ Anomaly Engine    │──▶│ PUC risk score   │
│ API (optional)  │    │ (offline-first,  │    │ (EWMA control     │    │ Fleet dashboard  │
│                 │    │  SQLite)         │    │  chart + CUSUM)   │    │ CO₂ reports      │
└─────────────────┘    └──────────────────┘    └───────────────────┘    └──────────────────┘
```

**Components:**
- **Mobile app** — Flutter (single codebase), with the trip-detection/recording service written natively on Android (Kotlin foreground service) because auto-start is the hero feature. iOS uses background location + motion triggers (silent recording; iOS forbids visible auto-launch).
- **Backend** — FastAPI (Python) + PostgreSQL + TimescaleDB extension for trip time-series. Python is deliberate: the emission model and statistics live in the same language as the data-science tooling used to calibrate them.
- **Emission engine** — pure, versioned, unit-tested Python module. Inputs: GPS trace + vehicle profile. Outputs: trip CO₂ (g), g/km, idle share, cold-start flag. Every stored trip records the engine version that scored it, so recalibration can re-score history.
- **Vehicle catalog** — make/model/year/fuel → BS stage, certified CO₂, engine size, COPERT class. Seeded from published ARAI/ICAT/COPERT data.

---

## 3. Full Feature Set (tiered)

### Tier 1 — Core MVP (the hackathon demo, weeks 1–8)
| # | Feature | Detail |
|---|---------|--------|
| 1 | Auto-start trip detection | Bluetooth pairing event (primary) + Activity Recognition "in_vehicle" (fallback). Zero-touch: enter car, drive, trip is recorded. |
| 2 | Trip recording | Adaptive GPS sampling (1 Hz moving, suspended at long idle), battery-aware. Persistent notification while recording (required + builds trust). |
| 3 | Per-trip CO₂ record | Distance, duration, idle time, estimated CO₂ (g), g/km, eco-score (0–100). |
| 4 | Emission dashboard | Today / week / month CO₂ totals; g/km trend line vs. personal baseline band; comparison vs. certified factory figure. |
| 5 | Vehicle profile | Pick make/model/year/fuel from catalog → loads emission factors. Multiple vehicles per account. |
| 6 | Offline-first | Trips stored locally, synced opportunistically. No connectivity needed while driving. |

### Tier 2 — The differentiators (weeks 8–16)
| # | Feature | Detail |
|---|---------|--------|
| 7 | Abnormal-emission alert | EWMA drift detection vs. personal baseline (see §5). Yellow at +10%, red alert at +20% sustained ≥5 of last 7 trips. |
| 8 | PUC failure prediction | Risk score for the next emission test from drift magnitude + idle-phase estimates. "High risk — service before your test on <date>." Stores PUC expiry date and reminds. |
| 9 | Service loop | Alert → checklist of likely causes (air filter, O₂ sensor, plugs, injectors) → "mark as serviced" → app verifies the drop back to baseline and shows "emissions recovered −18%." This closed loop is the emotional payoff. |
| 10 | Driving-style coach | Idle %, harsh accel/braking counts, speed-band time. Quantified: "Your idling added 1.2 kg CO₂ this week ≈ ₹95 of fuel." Money framing drives behavior. |
| 11 | Cold-start awareness | Flags short trips where the engine never warmed (2–4× dirtier per km); suggests trip-chaining. |
| 12 | Connected-car link | Optional OAuth link (Smartcar-style / manufacturer API) for real fuel data → accuracy upgrade badge on the dashboard. |

### Tier 3 — Real-world scale (months 4–12)
| # | Feature | Detail |
|---|---------|--------|
| 13 | MSME fleet dashboard | Web app: all vehicles, per-vehicle health flags, fleet CO₂/km league table, monthly PDF/CSV emission report (usable in green tenders & ESG disclosures). |
| 14 | Fleet driver mode | Driver phone auto-tags trips to vehicle via Bluetooth identity; owner sees per-driver eco-scores. |
| 15 | Garage partnerships | Alert deep-links to partner garages; garage confirms service performed; recovery verified by data. Referral revenue. |
| 16 | Carbon reports & offsets | Yearly personal/fleet carbon statement; optional offset purchase integration. |
| 17 | Community benchmarking | Anonymous percentile: "Your Swift emits less than 72% of Swifts in Chennai." |
| 18 | OBD-II pro tier (optional, later) | For power users who *choose* hardware — never required. Also serves as ongoing calibration fleet. |

---

## 4. Core Workflows

### W1 — Onboarding (target: < 4 minutes)
1. Sign in (phone OTP / Google).
2. Add vehicle: registration number → auto-fetch make/model where VAHAN-linked APIs allow, else manual pick.
3. Pair the car: "Turn on your car's Bluetooth and select it" → app remembers it as the trip trigger.
4. Permissions walkthrough (location "always", motion, notifications) — each with a one-line *why*.
5. Android OEM battery-whitelist step (Xiaomi/Oppo/Vivo kill background apps; this step is make-or-break for reliability in India).
6. Baseline notice: "Your first ~20 trips build your car's personal baseline. Insights sharpen as you drive."

### W2 — The invisible loop (every drive)
```
Car starts → phone pairs to car Bluetooth → OS wakes the app
  → foreground service starts, notification: "Trip recording"
  → GPS/IMU sampled adaptively; data buffered locally
Car stops → Bluetooth disconnects (or 5 min stationary)
  → trip closed → emission engine scores it (on-device first pass)
  → synced to backend → baseline & anomaly engines update
  → dashboard refreshed; notification only if something changed
```
Design rule: **zero interactions required.** The user can ignore the app for a month and the record is still complete.

### W3 — Anomaly → service → recovery (the flagship story)
1. Weeks of normal trips build the baseline (per speed-bucket: city/mixed/highway).
2. A fault develops (e.g., clogged air filter). Fuel-per-km — and thus estimated g/km — creeps up.
3. EWMA crosses +10%: trend turns yellow in-app. No noise yet.
4. Drift sustains ≥ +20% across 5 of 7 trips: push alert — "CO₂ up ~22% over your baseline for 2 weeks. Likely causes: air filter, spark plugs, O₂ sensor. Service recommended."
5. Owner services the car, taps "serviced."
6. Next trips confirm return to baseline → "Emissions recovered. You're saving ≈ ₹340/month in fuel vs. last month."
7. PUC test passes. The app takes credit with a shareable card. ← *this moment is the retention and referral engine.*

### W4 — MSME fleet weekly rhythm
Owner opens web dashboard Monday → fleet summary: total CO₂, per-vehicle g/km deltas, 2 vehicles flagged → books service for flagged vans → month-end: auto-generated emission report PDF attached to a client's green-logistics tender.

---

## 5. Algorithms (summary — full math in ALGORITHM.md when we build)

**Estimation:** COPERT speed-dependent emission factors per vehicle class `EF(v)`, applied per trip segment, plus idle rate (g/s by engine size), cold-start penalty (first 2–3 km), and harsh-acceleration penalties. When connected-car fuel data exists: `CO₂ = litres × 2.31 kg (petrol) / 2.68 kg (diesel)` — chemistry, not modeling.

**Baseline:** per-vehicle, per-speed-bucket robust baseline (median + MAD of last N=30 trips), so traffic weeks don't masquerade as engine faults.

**Drift detection:** EWMA control chart (λ=0.2) on baseline-normalized g/km; CUSUM as cross-check. Thresholds: watch +10% (~2σ), alert +20% (~3σ) sustained ≥5/7 trips, PUC-risk +25% with rising idle-phase estimates.

**Honest error budget:** absolute g/km ±10–15%; drift detection far tighter because each car is its own control — model bias cancels in the ratio.

---

## 6. Accuracy & Validation Strategy (the credibility moat)

This is what separates a real product from a hackathon toy:

1. **Calibration fleet (dev-time only):** during development, run 5–10 cars with a ₹1,000 OBD-II dongle logging real fuel-rate/MAF data *alongside* the app. Regress the software model against ground truth per vehicle class. **The dongle never ships to users — it exists only to prove and tune the model.** In demos, show the scatter plot: software estimate vs. OBD truth, R² on screen. Judges remember this slide.
2. **Versioned engine:** every trip stores `engine_version`; recalibration re-scores history so trends never silently jump.
3. **PUC ground truth:** users can photograph/enter PUC results; over time this builds the dataset linking our drift score to actual test outcomes — the basis for a real, published failure-prediction accuracy number.
4. **Published methodology page:** openly document factors and limits. Honesty about "estimate, not measurement" is a selling point under scrutiny, not a weakness.

---

## 7. Phased Roadmap

| Phase | Duration | Goal | Exit criteria |
|-------|----------|------|---------------|
| **0 — Validate** | 2 wks | Emission engine prototype in Python; replay recorded GPS traces; 1 car with OBD dongle for first calibration | Estimates within ±15% of OBD-derived CO₂ on test drives |
| **1 — MVP** | 6–8 wks | Android app: auto-start, trip recording, dashboard, vehicle catalog; backend + engine deployed | 10 friendly users, 30 days, >95% of real trips captured automatically |
| **2 — Detection** | 4–6 wks | Baseline + EWMA anomaly engine, alerts, service loop, PUC reminders | ≥1 genuine detected-and-fixed case documented (gold demo material) |
| **3 — Pilot** | 3 mo | 100–300 users incl. 3–5 MSME fleets; fleet web dashboard; calibration fleet to 10 cars | Retention >40% at 8 weeks; documented fuel savings; 1 fleet renewal |
| **4 — Scale** | 6–12 mo | iOS, connected-car integrations, garage partnerships, freemium switch-on | Unit economics positive on premium/fleet tiers |

**Team (min viable):** 1 mobile (Flutter + Android native), 1 backend/data (Python), 1 model/calibration owner (can overlap), 1 design/GTM. A 3–4 person student team maps cleanly onto this.

---

## 8. Business Model

- **Free:** trip records, CO₂ dashboard, basic alerts. (Distribution engine — never paywall the core promise.)
- **Premium ₹49–99/mo:** PUC prediction, service loop analytics, multi-vehicle, yearly carbon statement.
- **Fleet ₹99–199/vehicle/mo:** dashboard, driver scores, audit-ready CO₂ reports (billable to ESG/tender needs — MSMEs pay for reports that win them contracts).
- **Garage referrals:** bounty per verified serviced lead.
- **Later:** anonymized emission-trend data products for city planners/insurers (opt-in, aggregated only).

---

## 9. Regulatory & Privacy

- **Never claim PUC replacement.** Position: "pass your PUC on the first attempt." Regulatory tests require certified analyzers; we are the early-warning layer.
- **DPDP Act 2023 compliance:** explicit consent for location; on-device processing where possible; user-deletable data; no location sharing with third parties; fleet mode discloses tracking to drivers in-app.
- **Play Store background-location policy:** requires a prominent disclosure video + justification — prepare early, it's a common rejection reason.

---

## 10. Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| OEM battery killers stop background recording | Onboarding whitelist flow per OEM; Bluetooth event as wake trigger (more reliable than polling); missed-trip detection ("did you drive at 9:14? add trip") |
| Estimation accuracy challenged | Calibration-fleet evidence, published error bars, relative-drift framing, connected-car upgrade path |
| Users deny "always" location | Value-first onboarding: show a demo trip before asking; explain each permission at the moment it's needed |
| iOS restrictions weaken auto-start | Android-first market (India); iOS gets silent background recording — same records, no visible launch |
| Vehicle catalog gaps | Fallback to fuel-type + engine-size class defaults; user-editable; catalog grows from requests |
| Baseline gamed by route change (new job, new city) | Speed-bucket normalization + change-point detection resets baseline on sustained pattern shifts |

---

## 11. Hackathon Winning Strategy

The same build, staged for judges:

1. **Live demo of the invisible loop:** phone connects to a Bluetooth speaker (stand-in for a car), app auto-starts recording on stage. Then replay a real recorded drive through the engine live.
2. **The calibration scatter plot:** software vs. OBD ground truth. Instantly answers "but how accurate is it?" before it's asked.
3. **The recovery story:** one real (or pilot) case — drift chart rising, service, drop back to baseline, money saved. Narrative beats feature lists.
4. **The honesty card:** say "estimate, not measurement" *yourself*. Judges reward teams that know their limits.
5. **MSME hook:** fleet report PDF on screen — "this page wins a small logistics firm its next green tender."
6. **Scale math:** 30 crore+ vehicles, PUC legally mandatory, zero marginal hardware cost. One slide, three numbers.

**Metrics to show by demo day:** trips auto-captured %, estimation error vs. OBD, one detected anomaly, onboarding time.

---

## 12. KPIs (real-world)

- Auto-capture rate (target >95% of actual drives)
- Estimation error vs. calibration fleet (target ±10% per-trip, ±5% weekly aggregate)
- Alert precision (% of alerts confirmed by service findings — target >70%)
- 8-week retention >40%; fleet renewal rate >80%
- Documented fuel savings per alerted-and-serviced vehicle (₹/month)
