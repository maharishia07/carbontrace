/// API data models (mirror backend/app/schemas.py).
class Vehicle {
  final int id;
  final String name, make, model, classKey;
  final int year;
  final double odometerKm, calibrationFactor;
  final DateTime? calibratedAt;

  Vehicle.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'] ?? '',
        make = j['make'] ?? '',
        model = j['model'] ?? '',
        classKey = j['class_key'] ?? '',
        year = j['year'] ?? 0,
        odometerKm = (j['odometer_km'] as num? ?? 0).toDouble(),
        calibrationFactor = (j['calibration_factor'] as num? ?? 1).toDouble(),
        calibratedAt = j['calibrated_at'] != null
            ? DateTime.parse(j['calibrated_at'])
            : null;

  bool get fuelAnchored => calibratedAt != null;
}

class FillUpRec {
  final int id;
  final DateTime at;
  final double odometerKm, litres;
  final bool fullTank;
  final String source;

  FillUpRec.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        at = DateTime.parse(j['at']),
        odometerKm = (j['odometer_km'] as num).toDouble(),
        litres = (j['litres'] as num).toDouble(),
        fullTank = j['full_tank'] ?? true,
        source = j['source'] ?? 'manual';
}

class EconomySegment {
  final DateTime startAt, endAt;
  final double km, litres, lPer100km, measuredGpkm;
  final double? modeledGpkm, calibration;

  EconomySegment.fromJson(Map<String, dynamic> j)
      : startAt = DateTime.parse(j['start_at']),
        endAt = DateTime.parse(j['end_at']),
        km = (j['km'] as num).toDouble(),
        litres = (j['litres'] as num).toDouble(),
        lPer100km = (j['l_per_100km'] as num).toDouble(),
        measuredGpkm = (j['measured_gpkm'] as num).toDouble(),
        modeledGpkm =
            j['modeled_gpkm'] == null ? null : (j['modeled_gpkm'] as num).toDouble(),
        calibration =
            j['calibration'] == null ? null : (j['calibration'] as num).toDouble();
}

class Economy {
  final List<EconomySegment> segments;
  final double calibrationFactor;
  final DateTime? calibratedAt;
  final int fillups;

  Economy.fromJson(Map<String, dynamic> j)
      : segments = (j['segments'] as List<dynamic>? ?? [])
            .map((e) => EconomySegment.fromJson(e))
            .toList(),
        calibrationFactor = (j['calibration_factor'] as num? ?? 1).toDouble(),
        calibratedAt = j['calibrated_at'] != null
            ? DateTime.parse(j['calibrated_at'])
            : null,
        fillups = j['fillups'] ?? 0;
}

class Trip {
  final int id;
  final DateTime startedAt;
  final double distanceKm, durationS, idleS, co2G, gpkm, avgMovingSpeedKmh;
  final int harshEvents, ecoScore;
  final bool coldStart;
  final String bucket, source;

  Trip.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        startedAt = DateTime.parse(j['started_at']),
        distanceKm = (j['distance_km'] as num).toDouble(),
        durationS = (j['duration_s'] as num).toDouble(),
        idleS = (j['idle_s'] as num).toDouble(),
        co2G = (j['co2_g'] as num).toDouble(),
        gpkm = (j['gpkm'] as num).toDouble(),
        avgMovingSpeedKmh = (j['avg_moving_speed_kmh'] as num).toDouble(),
        harshEvents = j['harsh_events'] ?? 0,
        ecoScore = j['eco_score'] ?? 0,
        coldStart = j['cold_start'] ?? false,
        bucket = j['bucket'] ?? '',
        source = j['source'] ?? 'model';
}

class Health {
  final String status, message;
  final double driftPct, ewma;
  final int tripsAnalyzed, sustained;
  final bool idleRising, fuelBacked;
  final Map<String, double> baselines;

  Health.fromJson(Map<String, dynamic> j)
      : status = j['status'],
        message = j['message'] ?? '',
        driftPct = (j['drift_pct'] as num).toDouble(),
        ewma = (j['ewma'] as num).toDouble(),
        tripsAnalyzed = j['trips_analyzed'] ?? 0,
        sustained = j['sustained'] ?? 0,
        idleRising = j['idle_rising'] ?? false,
        fuelBacked = j['fuel_backed'] ?? false,
        baselines = (j['baselines'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble()));
}

class EmissionAlert {
  final int id;
  final DateTime createdAt;
  final String level, message;
  final double driftPct;
  final bool resolved;
  final DateTime? servicedAt;

  EmissionAlert.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        createdAt = DateTime.parse(j['created_at']),
        level = j['level'],
        message = j['message'] ?? '',
        driftPct = (j['drift_pct'] as num).toDouble(),
        resolved = j['resolved'] ?? false,
        servicedAt =
            j['serviced_at'] != null ? DateTime.parse(j['serviced_at']) : null;
}

class PeriodTotals {
  final int trips;
  final double distanceKm, co2Kg;
  final double? avgGpkm;

  PeriodTotals.fromJson(Map<String, dynamic> j)
      : trips = j['trips'] ?? 0,
        distanceKm = (j['distance_km'] as num? ?? 0).toDouble(),
        co2Kg = (j['co2_kg'] as num? ?? 0).toDouble(),
        avgGpkm = j['avg_gpkm'] == null ? null : (j['avg_gpkm'] as num).toDouble();
}

class TrendPoint {
  final DateTime date;
  final double gpkm;
  final String bucket;

  TrendPoint.fromJson(Map<String, dynamic> j)
      : date = DateTime.parse(j['date']),
        gpkm = (j['gpkm'] as num).toDouble(),
        bucket = j['bucket'] ?? '';
}

class Dashboard {
  final Vehicle vehicle;
  final PeriodTotals today, week, month;
  final Health health;
  final EmissionAlert? activeAlert;
  final List<TrendPoint> trend;

  Dashboard.fromJson(Map<String, dynamic> j)
      : vehicle = Vehicle.fromJson(j['vehicle']),
        today = PeriodTotals.fromJson(j['today']),
        week = PeriodTotals.fromJson(j['week']),
        month = PeriodTotals.fromJson(j['month']),
        health = Health.fromJson(j['health']),
        activeAlert = j['active_alert'] == null
            ? null
            : EmissionAlert.fromJson(j['active_alert']),
        trend = (j['trend'] as List<dynamic>? ?? [])
            .map((e) => TrendPoint.fromJson(e))
            .toList();
}

class VehicleClassOption {
  final String key, label, fuel;

  VehicleClassOption.fromJson(Map<String, dynamic> j)
      : key = j['key'],
        label = j['label'],
        fuel = j['fuel'];
}
