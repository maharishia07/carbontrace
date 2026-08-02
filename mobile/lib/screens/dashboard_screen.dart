import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/stat_tile.dart';
import '../widgets/trend_chart.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dash = state.dashboard;

    return Scaffold(
      appBar: AppBar(
        title: Text(state.vehicle?.name ?? 'CarbonTrace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: state.refresh,
        child: dash == null
            ? ListView(children: const [
                SizedBox(height: 200),
                Center(child: CircularProgressIndicator()),
              ])
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (state.error != null)
                    Card(
                      color: Colors.orange.shade50,
                      child: ListTile(
                        leading: const Icon(Icons.wifi_off, color: Colors.orange),
                        title: Text(state.error!,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  _HealthBanner(),
                  const SizedBox(height: 4),
                  Row(children: [
                    StatTile(
                        label: 'Today',
                        value: '${dash.today.co2Kg} kg',
                        caption: '${dash.today.trips} trips'),
                    StatTile(
                        label: 'This week',
                        value: '${dash.week.co2Kg} kg',
                        caption: '${dash.week.distanceKm.toStringAsFixed(0)} km'),
                    StatTile(
                        label: '30 days',
                        value: '${dash.month.co2Kg} kg',
                        caption: dash.month.avgGpkm == null
                            ? '—'
                            : '${dash.month.avgGpkm!.toStringAsFixed(0)} g/km avg'),
                  ]),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CO₂ per km — recent trips',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(
                            dash.health.baselines.containsKey('city')
                                ? 'Shaded band = your car\'s normal range'
                                : 'Baseline appears after ~8 trips per driving type',
                            style: const TextStyle(
                                fontSize: 11.5, color: Colors.black54),
                          ),
                          TrendChart(
                            points: dash.trend,
                            baseline: dash.health.baselines['city'],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _HealthBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final health = state.dashboard!.health;
    final color = CtColors.statusColor(health.status);

    return Card(
      color: color.withValues(alpha: 0.09),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(CtColors.statusIcon(health.status), color: color, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(CtColors.statusLabel(health.status),
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(health.message,
                      style:
                          const TextStyle(fontSize: 12.5, color: Colors.black87)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
