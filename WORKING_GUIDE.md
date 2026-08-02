# CarbonTrace — Working Guide (live build log)

This file tracks build progress. Updated with every push.

## Status board

| # | Milestone | Status | Notes |
|---|-----------|--------|-------|
| 1 | Repo + GitHub setup | ✅ done | https://github.com/maharishia07/carbontrace |
| 2 | Emission engine + anomaly detector | ✅ done | COPERT-style EF(v), idle/cold-start, fuel-chemistry path, EWMA drift — 19 tests pass |
| 3 | FastAPI backend + trip simulator | ✅ done | vehicles, trips, health, alerts, serviced, dashboard; demo seeder fires a real alert (+27% drift) |
| 4 | Flutter app source | ✅ written (not yet compiled) | full app: 6 screens, trend chart, recorder — needs Flutter SDK for first build |
| 5 | Android native auto-start service | ✅ written (not yet compiled) | Kotlin foreground service + Bluetooth ACL receiver in mobile/android_native/ |
| 6 | First Flutter build | ⬜ pending | install Flutter SDK → `flutter create .` → merge android_native/ → `flutter run` |
| 7 | Real-device testing | ⬜ pending | needs a physical Android phone + car |
| 8 | OBD calibration drives | ⬜ pending | needs a ₹1,000 OBD-II dongle, dev-time only |
| 9 | Play Store submission | ⬜ pending | background-location disclosure video required |

## How to run (current state)

```bash
cd backend
pip install -r requirements.txt
pytest                          # verify everything
uvicorn app.main:app --reload   # API at http://127.0.0.1:8000/docs
python -m app.demo              # seed demo vehicle + simulated healthy→degraded trips
```

## Build log

### 2026-08-02
- Project started. git repo initialized, execution plan and pitch deck committed.
- Toolchain: Python 3.11 (FastAPI/pytest ready), Node 24, gh CLI authenticated. Flutter SDK **not** installed — mobile source will be written compile-ready and verified once SDK is available.
- **Backend shipped**: emission engine (COPERT-shaped EF(v) + idle + cold-start + harsh-accel; fuel-chemistry path when litres known), per-bucket baseline + EWMA drift detector, full REST API, deterministic trip simulator. 19/19 tests pass. One bug found & fixed: "recovered" notices were created as open alerts.
- **Demo verified**: 40 healthy + 15 degraded (+30% fuel) trips → alert fires at +27.3% drift with 7/7 sustained trips.
- **Flutter app source written** (13 Dart/Kotlin files): dashboard with CVD-validated status palette + custom trend chart with baseline band, trips list/detail, manual+auto record screen, health screen with mark-serviced loop, vehicle setup, settings. Android auto-start layer (foreground service + Bluetooth ACL receiver) in `mobile/android_native/` with merge instructions. **Not compiled yet** — Flutter SDK missing on this machine; expect minor first-build fixes.

### Next session
1. Install Flutter SDK → first build (`flutter create .`, merge android_native/, `flutter run`).
2. Test auto-start against a real car / Bluetooth speaker.
3. Optional: OBD calibration drives for the accuracy scatter plot.

## Decisions record

- **Stack:** Flutter (Android-first) + FastAPI + SQLite (dev) / PostgreSQL (prod).
- **Estimation:** COPERT speed-dependent factors + idle + cold-start + harsh-accel penalties; fuel-based chemistry (2.31 kg CO₂/L petrol, 2.68 diesel) when connected-car fuel data exists.
- **Anomaly:** per-vehicle per-speed-bucket baseline (median+MAD, N=30), EWMA λ=0.2; watch +10 %, alert +20 % sustained ≥5/7 trips, PUC risk +25 % with rising idle emissions.
- **Honesty rule:** always "estimate", never "measurement"; never claim PUC replacement.

## Next actions

1. Emission engine module + unit tests.
2. Backend API + simulator + demo seed.
3. Flutter app source + Android Kotlin service.
4. Create GitHub repo, push, keep this guide updated every push.
