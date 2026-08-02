import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final trips = state.trips;

    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      body: RefreshIndicator(
        onRefresh: state.refresh,
        child: trips.isEmpty
            ? ListView(children: const [
                SizedBox(height: 160),
                Center(
                    child: Text(
                        'No trips yet.\nDrive with auto-record on, or use the Record tab.',
                        textAlign: TextAlign.center)),
              ])
            : ListView.builder(
                itemCount: trips.length,
                itemBuilder: (_, i) => _TripTile(trip: trips[i]),
              ),
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  final Trip trip;
  const _TripTile({required this.trip});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE d MMM, h:mm a').format(trip.startedAt.toLocal());
    final co2 = trip.co2G >= 1000
        ? '${(trip.co2G / 1000).toStringAsFixed(2)} kg'
        : '${trip.co2G.toStringAsFixed(0)} g';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green.shade50,
        child: Icon(
          switch (trip.bucket) {
            'highway' => Icons.add_road,
            'mixed' => Icons.route,
            _ => Icons.location_city,
          },
          color: Colors.green.shade800,
          size: 20,
        ),
      ),
      title: Text('$co2 CO₂  ·  ${trip.distanceKm.toStringAsFixed(1)} km',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(
          '$date  ·  ${trip.gpkm.toStringAsFixed(0)} g/km  ·  eco ${trip.ecoScore}'),
      trailing: trip.source == 'fuel'
          ? const Tooltip(
              message: 'Backed by real fuel data',
              child: Icon(Icons.verified, size: 18, color: Colors.teal))
          : null,
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (_) => _TripDetail(trip: trip),
      ),
    );
  }
}

class _TripDetail extends StatelessWidget {
  final Trip trip;
  const _TripDetail({required this.trip});

  @override
  Widget build(BuildContext context) {
    String mins(double s) => '${(s / 60).toStringAsFixed(0)} min';
    final rows = <(String, String)>[
      ('Distance', '${trip.distanceKm.toStringAsFixed(2)} km'),
      ('Duration', mins(trip.durationS)),
      ('Idling', '${mins(trip.idleS)} '
          '(${(trip.idleS / trip.durationS * 100).toStringAsFixed(0)}%)'),
      ('Avg moving speed', '${trip.avgMovingSpeedKmh.toStringAsFixed(0)} km/h'),
      ('CO₂', '${trip.co2G.toStringAsFixed(0)} g (${trip.gpkm.toStringAsFixed(1)} g/km)'),
      ('Harsh accelerations', '${trip.harshEvents}'),
      ('Cold start', trip.coldStart ? 'Yes' : 'No'),
      ('Eco score', '${trip.ecoScore}/100'),
      ('Data source', trip.source == 'fuel' ? 'Fuel data' : 'Model estimate'),
    ];
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trip details',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(r.$1,
                            style: const TextStyle(color: Colors.black54))),
                    Text(r.$2,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
