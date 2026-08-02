# Android native layer — setup

The Flutter SDK generates the platform scaffolding; these files add the
auto-start machinery on top of it. One-time setup:

```bash
cd mobile
flutter create . --org com.carbontrace --project-name carbontrace --platforms android
flutter pub get
```

Then wire in the native pieces:

1. Copy `MainActivity.kt`, `TripRecordingService.kt`, `BluetoothTripReceiver.kt`
   into `android/app/src/main/kotlin/com/carbontrace/app/`
   (replace the generated `MainActivity.kt`).
2. Merge `AndroidManifest-additions.xml` into
   `android/app/src/main/AndroidManifest.xml` — permissions above
   `<application>`, the `<service>` and `<receiver>` inside it.
3. In `android/app/build.gradle`, set `minSdkVersion 26`.
4. Build: `flutter run` (phone connected, USB debugging on).

## How auto-start works

```
Car ignition on → car Bluetooth powers up → phone auto-connects
  → BluetoothTripReceiver (ACL_CONNECTED)
  → starts TripRecordingService as a foreground service (persistent notification)
  → service reuses/creates the Flutter engine and calls Dart "autoStart"
  → Dart TripRecorder streams GPS until Bluetooth disconnects or 5 min parked
  → trip uploads to the backend and the dashboard refreshes
```

## Real-phone checklist (India-market OEMs)

- Settings → Battery → CarbonTrace → **No restrictions** (Xiaomi/Oppo/Vivo/Realme
  kill background services by default — this is the #1 reliability issue).
- Location permission must be **"Allow all the time"** for auto-recording.
- Android 12+: Bluetooth permission prompt (`BLUETOOTH_CONNECT`) appears on
  first launch — required to detect the car connection.
- During onboarding the app stores the car's Bluetooth MAC as
  `car_bt_address`; until set, any hands-free connect triggers recording.
