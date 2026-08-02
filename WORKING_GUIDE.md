# CarbonTrace — Working Guide (live build log)

This file tracks build progress. Updated with every push.

## Status board

| # | Milestone | Status | Notes |
|---|-----------|--------|-------|
| 1 | Repo + GitHub setup | 🔄 in progress | git init done, GitHub repo pending |
| 2 | Emission engine + anomaly detector | ⬜ pending | COPERT-style EF(v), idle/cold-start, EWMA drift |
| 3 | FastAPI backend + trip simulator | ⬜ pending | vehicles, trips, dashboard, alerts endpoints |
| 4 | Flutter app source | ⬜ pending | SDK not installed on dev machine — source written compile-ready |
| 5 | Android native auto-start service | ⬜ pending | Kotlin foreground service + Bluetooth receiver |
| 6 | Real-device testing | ⬜ pending | needs a physical Android phone + car |
| 7 | OBD calibration drives | ⬜ pending | needs a ₹1,000 OBD-II dongle, dev-time only |
| 8 | Play Store submission | ⬜ pending | background-location disclosure video required |

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
