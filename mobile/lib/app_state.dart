import 'dart:convert';

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
  double fuelPricePerLitre = 102.0; // editable in Settings
  String? lastAutoFillupNote; // surfaced once after an automatic capture

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
    fuelPricePerLitre = prefs.getDouble('fuelPrice') ?? 102.0;
    final vid = prefs.getInt('vehicleId');
    if (vid != null) {
      await selectVehicle(vid);
    }
    notifyListeners();
  }

  Future<void> setFuelPrice(double price) async {
    fuelPricePerLitre = price;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('fuelPrice', price);
    notifyListeners();
  }

  /// Convert payment notifications captured by the native listener into
  /// automatic fill-ups: litres = amount / fuel price, odometer virtual.
  Future<void> _processPendingPayments() async {
    if (vehicle == null || vehicle!.odometerKm <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('pending_fuel_payments');
    if (raw == null || raw.isEmpty) return;
    List<dynamic> pending;
    try {
      pending = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      await prefs.remove('pending_fuel_payments');
      return;
    }
    if (pending.isEmpty) return;

    var logged = 0;
    for (final e in pending) {
      final amount = (e['amount_inr'] as num?)?.toDouble();
      final t = (e['t'] as num?)?.toDouble();
      if (amount == null || t == null) continue;
      final at = DateTime.fromMillisecondsSinceEpoch((t * 1000).round());
      // ignore stale captures (older than 24h)
      if (DateTime.now().difference(at) > const Duration(hours: 24)) continue;
      final litres = amount / fuelPricePerLitre;
      if (litres < 1 || litres > 120) continue;
      try {
        await api.addFillUp(vehicle!.id,
            litres: double.parse(litres.toStringAsFixed(2)), fullTank: true);
        logged++;
        lastAutoFillupNote =
            'Auto-logged fill-up: ₹${amount.toStringAsFixed(0)} ≈ '
            '${litres.toStringAsFixed(1)} L (from your payment notification)';
      } catch (_) {
        // backend unreachable — keep pending for next refresh
        return;
      }
    }
    if (logged > 0) {
      await prefs.remove('pending_fuel_payments');
    }
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
      // zero-touch fill-ups: fold in any captured fuel payments
      final before = lastAutoFillupNote;
      await _processPendingPayments();
      if (lastAutoFillupNote != before) {
        dashboard = await api.dashboard(vehicleId);
        economy = await api.economy(vehicleId);
      }
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
