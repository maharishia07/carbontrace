# CarbonTrace mobile app (Flutter)

Android-first Flutter app: auto-start trip recording, CO₂ dashboard, trip
history, engine-health alerts and the service/recovery loop.

## Structure

```
lib/
  main.dart                     app entry + bottom navigation
  theme.dart                    brand + CVD-validated status palette
  models.dart                   API models (mirror backend schemas)
  api_client.dart               REST client for the backend
  app_state.dart                global state (vehicle, dashboard, prefs)
  services/trip_recorder.dart   GPS trip recording (manual + auto-start)
  screens/
    dashboard_screen.dart       stat tiles, health banner, g/km trend chart
    trips_screen.dart           trip list + per-trip detail sheet
    record_screen.dart          manual record + auto-record status
    health_screen.dart          health report, mark-serviced, alert history
    vehicle_setup_screen.dart   first-run vehicle registration
    settings_screen.dart        server URL, auto-record, battery help
  widgets/
    trend_chart.dart            CustomPainter g/km line + baseline band
    stat_tile.dart              hero-number tiles
android_native/                 Kotlin auto-start layer + merge instructions
```

## Build

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(not installed on the original dev machine — this source is written
compile-ready but has not been built yet; expect minor fixes on first build).

```bash
cd mobile
flutter create . --org com.carbontrace --project-name carbontrace --platforms android
flutter pub get
# wire in the native auto-start layer: see android_native/README.md
flutter run
```

## Pointing the app at the backend

Start the backend (`uvicorn app.main:app --host 0.0.0.0` in `backend/`), then
in the app's Settings set the server URL:

- Android emulator: `http://10.0.2.2:8000`
- Real phone on the same Wi-Fi: `http://<your PC's LAN IP>:8000`

For a quick demo without driving: `python -m app.demo` on the backend seeds
"Demo Swift" with 55 trips ending in a live service alert — select it on the
app's vehicle screen.
