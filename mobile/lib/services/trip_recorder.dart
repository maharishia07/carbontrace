import 'dart:async';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// A completed recording ready for upload.
class RecordedTrip {
  final DateTime startedAt;
  final List<Map<String, dynamic>> points; // {t, lat, lon, speed_kmh}
  final bool coldStart;

  RecordedTrip(this.startedAt, this.points, {this.coldStart = false});
}

/// Records GPS points during a drive.
///
/// Started two ways:
///  - manually from the Record screen, or
///  - automatically by the Android native layer (Bluetooth connect to the
///    car / activity recognition) via the `carbontrace/recorder` channel.
///
/// Ends when stop() is called or after [autoStopAfter] without movement.
class TripRecorder {
  static const _channel = MethodChannel('carbontrace/recorder');
  static const autoStopAfter = Duration(minutes: 5);
  static const _minTripPoints = 20;

  bool recording = false;
  DateTime? startedAt;
  DateTime? _lastMovement;
  final List<Map<String, dynamic>> _points = [];
  StreamSubscription<Position>? _sub;
  Timer? _idleCheck;

  Future<void> Function(RecordedTrip trip)? onTripCompleted;
  void Function()? onStateChanged;

  TripRecorder() {
    _channel.setMethodCallHandler((call) async {
      // Native side asks Dart to start/stop (auto-start flow).
      switch (call.method) {
        case 'autoStart':
          await start();
        case 'autoStop':
          await stop();
      }
    });
  }

  int get pointCount => _points.length;

  Future<bool> ensurePermissions() async {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  Future<void> start() async {
    if (recording) return;
    if (!await ensurePermissions()) return;

    recording = true;
    startedAt = DateTime.now();
    _lastMovement = DateTime.now();
    _points.clear();

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen(_onPosition);

    _idleCheck = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_lastMovement != null &&
          DateTime.now().difference(_lastMovement!) > autoStopAfter) {
        stop(); // parked long enough — close the trip
      }
    });
    onStateChanged?.call();
  }

  void _onPosition(Position pos) {
    final speedKmh = (pos.speed.isFinite ? pos.speed : 0.0) * 3.6;
    _points.add({
      't': pos.timestamp.millisecondsSinceEpoch / 1000.0,
      'lat': pos.latitude,
      'lon': pos.longitude,
      'speed_kmh': double.parse(speedKmh.toStringAsFixed(1)),
    });
    if (speedKmh > 3.0) _lastMovement = DateTime.now();
  }

  Future<void> stop() async {
    if (!recording) return;
    recording = false;
    await _sub?.cancel();
    _idleCheck?.cancel();

    if (_points.length >= _minTripPoints && startedAt != null) {
      final trip = RecordedTrip(startedAt!, List.of(_points));
      await onTripCompleted?.call(trip);
    }
    _points.clear();
    onStateChanged?.call();
  }
}
