import 'package:flutter_test/flutter_test.dart';

import 'package:carbontrace/models.dart';

void main() {
  test('dashboard payload parses', () {
    final dash = Dashboard.fromJson({
      'vehicle': {
        'id': 1,
        'name': 'Demo Swift',
        'make': 'Maruti',
        'model': 'Swift',
        'year': 2021,
        'class_key': 'hatch_petrol',
      },
      'today': {'trips': 1, 'distance_km': 5.2, 'co2_kg': 0.7, 'avg_gpkm': 135},
      'week': {'trips': 6, 'distance_km': 48.0, 'co2_kg': 6.1, 'avg_gpkm': 127},
      'month': {'trips': 20, 'distance_km': 210.0, 'co2_kg': 27.2, 'avg_gpkm': 129},
      'health': {
        'status': 'alert',
        'message': 'Service recommended',
        'drift_pct': 24.5,
        'ewma': 1.245,
        'trips_analyzed': 55,
        'sustained': 6,
        'idle_rising': true,
        'fuel_backed': true,
        'baselines': {'city': 148.2},
      },
      'active_alert': {
        'id': 3,
        'vehicle_id': 1,
        'created_at': '2026-08-01T09:00:00',
        'level': 'alert',
        'message': 'CO2 up',
        'drift_pct': 24.5,
        'resolved': false,
        'serviced_at': null,
      },
      'trend': [
        {'date': '2026-07-30T09:00:00', 'gpkm': 150.1, 'bucket': 'city'},
        {'date': '2026-07-31T09:00:00', 'gpkm': 182.4, 'bucket': 'city'},
      ],
    });

    expect(dash.vehicle.name, 'Demo Swift');
    expect(dash.health.status, 'alert');
    expect(dash.activeAlert, isNotNull);
    expect(dash.trend.length, 2);
    expect(dash.health.baselines['city'], closeTo(148.2, 0.001));
  });
}
