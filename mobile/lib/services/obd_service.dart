import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// ECU data over an ELM327 OBD-II Bluetooth adapter (optional hardware).
///
/// When connected, polls the ECU once a second. MAF airflow gives real-time
/// fuel burn (petrol stoichiometry: fuel g/s = MAF/14.7; litres via density
/// 737 g/L), which accumulates per trip and replaces the model entirely.
class ObdService {
  static const _channel = MethodChannel('carbontrace/obd');
  static const _airFuelRatio = 14.7;
  static const _petrolDensityGPerL = 737.0;

  final ValueNotifier<Map<String, double?>?> latest = ValueNotifier(null);
  bool connected = false;
  double _tripLitres = 0.0;
  Timer? _poll;

  Future<List<Map<String, String>>> pairedDevices() async {
    final r = await _channel.invokeMethod<List<dynamic>>('pairedDevices');
    return (r ?? [])
        .map((e) => Map<String, String>.from(e as Map))
        .toList();
  }

  Future<bool> connect(String address) async {
    final ok = await _channel.invokeMethod<bool>('connect', {'address': address});
    connected = ok ?? false;
    if (connected) {
      _poll = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
    return connected;
  }

  Future<void> disconnect() async {
    _poll?.cancel();
    _poll = null;
    connected = false;
    latest.value = null;
    await _channel.invokeMethod('disconnect');
  }

  Future<void> _tick() async {
    try {
      final r = await _channel.invokeMethod<Map<dynamic, dynamic>>('read');
      if (r == null) return;
      final snap = r.map((k, v) => MapEntry(k.toString(), (v as num?)?.toDouble()));
      latest.value = snap;
      final maf = snap['maf_g_s'];
      if (maf != null && maf > 0) {
        _tripLitres += (maf / _airFuelRatio) / _petrolDensityGPerL; // per 1s tick
      }
    } catch (_) {
      // adapter hiccup — keep polling
    }
  }

  /// Fuel used since last consume; call when a trip closes.
  double consumeTripLitres() {
    final litres = _tripLitres;
    _tripLitres = 0.0;
    return litres;
  }

  void resetTrip() => _tripLitres = 0.0;
}
