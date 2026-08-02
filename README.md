# CarbonTrace

**A fully software-based carbon emission monitor for cars — no sensors, no OBD dongles, no hardware.**

CarbonTrace is a mobile app + cloud backend that estimates a car's CO₂ emissions continuously from data the car and phone already produce (car Bluetooth as the ignition trigger, phone GPS/motion for the drive profile), builds a per-vehicle emission baseline, and alerts the owner when emissions drift abnormally — so the car gets serviced *before* it pollutes heavily or fails a PUC test.

> Estimate, not measurement: no software can measure tailpipe gas. CarbonTrace models emissions from driving physics (COPERT/BS6 emission factors) and detects degradation statistically against each car's own baseline — which is exactly what makes early-warning possible with zero hardware.

## Repository layout

```
backend/          FastAPI backend: emission engine, anomaly detection, REST API
mobile/           Flutter app (Android-first): auto-start trip recording, dashboard
EXECUTION_PLAN.md Full real-world execution blueprint
WORKING_GUIDE.md  Live build log: what's done, what's next, how to run everything
```

## Quick start (backend)

```bash
cd backend
pip install -r requirements.txt
pytest                             # run the test suite
uvicorn app.main:app --reload      # start the API at http://127.0.0.1:8000
python -m app.demo                 # seed a demo vehicle + simulated trips (healthy → degraded)
```

Interactive API docs: http://127.0.0.1:8000/docs

## Quick start (mobile)

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install). Then:

```bash
cd mobile
flutter pub get
flutter run
```

## The core loop

1. Car starts → phone pairs with car Bluetooth → app auto-starts trip recording.
2. GPS/motion data → COPERT-style speed-dependent emission model → CO₂ per trip, g/km.
3. Every trip updates the car's personal baseline (bucketed city/mixed/highway).
4. EWMA control chart watches for drift: **+10 % → watch**, **+20 % sustained (5 of 7 trips) → service alert**, **+25 % + rising idle emissions → PUC-failure risk**.
5. Owner services the car → app verifies emissions return to baseline and quantifies the fuel money saved.

## Status

MVP under active development — see [WORKING_GUIDE.md](WORKING_GUIDE.md) for the live build log.

*Built for the MSME Hackathon 2026.*
