import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final trips = state.trips;

    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      body: RefreshIndicator(
        color: CtColors.brand,
        onRefresh: state.refresh,
        child: trips.isEmpty
            ? ListView(children: const [
                SizedBox(height: 140),
                Icon(Icons.route_rounded, size: 56, color: CtColors.inkFaint),
                SizedBox(height: 12),
                Center(
                    child: Text(
                        'No trips yet.\nDrive with auto-record on, or use the Record tab.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: CtColors.inkSecondary))),
              ])
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: trips.length,
                itemBuilder: (_, i) => _TripCard(trip: trips[i]),
              ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  const _TripCard({required this.trip});

  Color get _scoreColor => trip.ecoScore >= 75
      ? CtColors.ok
      : trip.ecoScore >= 50
          ? CtColors.watch
          : CtColors.alert;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE d MMM · h:mm a').format(trip.startedAt.toLocal());
    final co2 = trip.co2G >= 1000
        ? '${(trip.co2G / 1000).toStringAsFixed(2)} kg'
        : '${trip.co2G.toStringAsFixed(0)} g';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CtColors.divider),
        boxShadow: ctShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => showModalBottomSheet(
          context: context,
          builder: (_) => _TripDetail(trip: trip),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // eco score ring
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: trip.ecoScore / 100,
                      strokeWidth: 4,
                      color: _scoreColor,
                      backgroundColor: CtColors.divider,
                    ),
                    Text('${trip.ecoScore}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _scoreColor)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('$co2 CO₂',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: CtColors.ink)),
                      const SizedBox(width: 8),
                      Text('${trip.distanceKm.toStringAsFixed(1)} km',
                          style: const TextStyle(
                              fontSize: 13, color: CtColors.inkSecondary)),
                      if (trip.source == 'fuel') ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded,
                            size: 15, color: CtColors.ok),
                      ],
                    ]),
                    const SizedBox(height: 3),
                    Text(
                        '$date  ·  ${trip.gpkm.toStringAsFixed(0)} g/km  ·  ${trip.bucket}',
                        style: const TextStyle(
                            fontSize: 12, color: CtColors.inkFaint)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: CtColors.inkFaint),
            ],
          ),
        ),
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
      ('Idling',
          '${mins(trip.idleS)} (${(trip.idleS / trip.durationS * 100).toStringAsFixed(0)}%)'),
      ('Avg moving speed', '${trip.avgMovingSpeedKmh.toStringAsFixed(0)} km/h'),
      ('CO₂',
          '${trip.co2G.toStringAsFixed(0)} g  ·  ${trip.gpkm.toStringAsFixed(1)} g/km'),
      ('Harsh accelerations', '${trip.harshEvents}'),
      ('Cold start', trip.coldStart ? 'Yes' : 'No'),
      if (trip.refuelStop) ('Fuel-station stop', 'Detected'),
      ('Eco score', '${trip.ecoScore}/100'),
      ('Data source',
          trip.source == 'fuel' ? 'Measured fuel' : 'Model estimate'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: CtColors.divider,
                borderRadius: BorderRadius.circular(4)),
          ),
          Text('Trip details',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(r.$1,
                            style: const TextStyle(
                                color: CtColors.inkSecondary, fontSize: 13.5))),
                    Text(r.$2,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
