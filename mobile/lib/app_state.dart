import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'models.dart';
import 'services/trip_recorder.dart';

/// Global app state: server config, selected vehicle, cached dashboard.
class AppState extends ChangeNotifier {
  // 10.0.2.2 reaches the host machine from the Android emulator.
  static const defaultServer = 'http://10.0.2.2:8000';

  final ApiClient api = ApiClient(defaultServer);
  final TripRecorder recorder = TripRecorder();

  Vehicle? vehicle;
  Dashboard? dashboard;
  List<Trip> trips = [];
  List<EmissionAlert> alerts = [];
  String? error;
  bool loading = false;
  bool autoRecordEnabled = true;

  AppState() {
    recorder.onTripCompleted = _onTripCompleted;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    api.baseUrl = prefs.getString('server') ?? defaultServer;
    autoRecordEnabled = prefs.getBool('autoRecord') ?? true;
    final vid = prefs.getInt('vehicleId');
    if (vid != null) {
      await selectVehicle(vid);
    }
    notifyListeners();
  }

  Future<void> setServer(String url) async {
    api.baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server', api.baseUrl);
    notifyListeners();
  }

  Future<void> setAutoRecord(bool value) async {
    autoRecordEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoRecord', value);
    notifyListeners();
  }

  Future<void> selectVehicle(int vehicleId) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      dashboard = await api.dashboard(vehicleId);
      vehicle = dashboard!.vehicle;
      trips = await api.trips(vehicleId);
      alerts = await api.alerts(vehicleId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('vehicleId', vehicleId);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (vehicle != null) await selectVehicle(vehicle!.id);
  }

  Future<Vehicle> registerVehicle({
    required String name,
    required String make,
    required String model,
    required int year,
    required String classKey,
  }) async {
    final v = await api.createVehicle(
        name: name, make: make, model: model, year: year, classKey: classKey);
    await selectVehicle(v.id);
    return v;
  }

  Future<void> markServiced() async {
    if (vehicle == null) return;
    await api.markServiced(vehicle!.id);
    await refresh();
  }

  Future<void> _onTripCompleted(RecordedTrip t) async {
    if (vehicle == null) return;
    try {
      await api.uploadTrip(
        vehicle!.id,
        startedAt: t.startedAt,
        points: t.points,
        coldStart: t.coldStart,
      );
      await refresh();
    } catch (e) {
      // Trip stays in the recorder's pending queue for retry on next launch.
      error = 'Trip upload failed — will retry: $e';
      notifyListeners();
    }
  }
}
