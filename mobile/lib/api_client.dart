import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Thin REST client for the CarbonTrace backend.
class ApiClient {
  String baseUrl;

  ApiClient(this.baseUrl);

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  Future<List<VehicleClassOption>> catalog() async {
    final r = await http.get(_u('/catalog'));
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => VehicleClassOption.fromJson(e))
        .toList();
  }

  Future<List<Vehicle>> vehicles() async {
    final r = await http.get(_u('/vehicles'));
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => Vehicle.fromJson(e)).toList();
  }

  Future<Vehicle> createVehicle({
    required String name,
    required String make,
    required String model,
    required int year,
    required String classKey,
  }) async {
    final r = await http.post(
      _u('/vehicles'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'make': make,
        'model': model,
        'year': year,
        'class_key': classKey,
      }),
    );
    _check(r);
    return Vehicle.fromJson(jsonDecode(r.body));
  }

  Future<Dashboard> dashboard(int vehicleId) async {
    final r = await http.get(_u('/vehicles/$vehicleId/dashboard'));
    _check(r);
    return Dashboard.fromJson(jsonDecode(r.body));
  }

  Future<List<Trip>> trips(int vehicleId, {int limit = 100}) async {
    final r = await http.get(_u('/vehicles/$vehicleId/trips?limit=$limit'));
    _check(r);
    return (jsonDecode(r.body) as List).map((e) => Trip.fromJson(e)).toList();
  }

  Future<List<EmissionAlert>> alerts(int vehicleId) async {
    final r = await http.get(_u('/vehicles/$vehicleId/alerts'));
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => EmissionAlert.fromJson(e))
        .toList();
  }

  Future<void> markServiced(int vehicleId) async {
    final r = await http.post(_u('/vehicles/$vehicleId/serviced'));
    _check(r);
  }

  /// Upload a recorded trip. [points] items: {t, lat, lon, speed_kmh?}.
  Future<Trip> uploadTrip(
    int vehicleId, {
    required DateTime startedAt,
    required List<Map<String, dynamic>> points,
    bool coldStart = false,
    double? fuelLitres,
  }) async {
    final r = await http.post(
      _u('/vehicles/$vehicleId/trips'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'started_at': startedAt.toUtc().toIso8601String(),
        'points': points,
        'cold_start': coldStart,
        'fuel_litres': fuelLitres,
      }),
    );
    _check(r);
    return Trip.fromJson(jsonDecode(r.body));
  }

  void _check(http.Response r) {
    if (r.statusCode >= 400) {
      throw ApiException(r.statusCode, r.body);
    }
  }
}

class ApiException implements Exception {
  final int status;
  final String body;
  ApiException(this.status, this.body);

  @override
  String toString() => 'API error $status: $body';
}
