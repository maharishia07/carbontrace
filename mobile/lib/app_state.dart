import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'models.dart';
import 'services/obd_service.dart';
import 'services/trip_recorder.dart';

/// Global app state: server config, selected vehicle, cached dashboard.
class AppState extends ChangeNotifier {
  // 10.0.2.2 reaches the host machine from the Android emulator.
  static const defaultServer = 'http://10.0.2.2:8000';

  final ApiClient api = ApiClient(defaultServer);
  final TripRecorder recorder = TripRecorder();
  final ObdService obd = ObdService();

  Vehicle? vehicle;
  Dashboard? dashboard;
  List<Trip> trips = [];
  List<EmissionAlert> alerts = [];
  Economy? economy;
  String? error;
  bool loading = false;
  bool autoRecordEnabled = true;

  AppState() {
    recorder.onTripCompleted = _onTripCompleted;
    recorder.onStateChanged = () {
      if (recorder.recording) obd.resetTrip(); // fuel counts per trip
      notifyListeners();
    };
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
      economy = await api.economy(vehicleId);
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

  /// Forget the selected vehicle and return to the vehicle list.
  Future<void> clearVehicle() async {
    vehicle = null;
    dashboard = null;
    trips = [];
    alerts = [];
    economy = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('vehicleId');
    notifyListeners();
  }

  Future<void> setOdometer(double km) async {
    if (vehicle == null) return;
    await api.setOdometer(vehicle!.id, km);
    await refresh();
  }

  Future<void> logFillUp(
      {required double litres, double? odometerKm, bool fullTank = true}) async {
    if (vehicle == null) return;
    await api.addFillUp(vehicle!.id,
        litres: litres, odometerKm: odometerKm, fullTank: fullTank);
    await refresh();
  }

  Future<void> syncConnectedCar() async {
    if (vehicle == null) return;
    await api.connectedSync(vehicle!.id);
    await refresh();
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
    // with an OBD adapter connected, the ECU measured the fuel directly
    final obdLitres = obd.consumeTripLitres();
    try {
      await api.uploadTrip(
        vehicle!.id,
        startedAt: t.startedAt,
        points: t.points,
        coldStart: t.coldStart,
        fuelLitres: obdLitres > 0.05 ? obdLitres : null,
      );
      await refresh();
    } catch (e) {
      // Trip stays in the recorder's pending queue for retry on next launch.
      error = 'Trip upload failed — will retry: $e';
      notifyListeners();
    }
  }
}
