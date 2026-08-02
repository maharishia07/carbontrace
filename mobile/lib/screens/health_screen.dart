import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final health = state.dashboard?.health;
    final active = state.dashboard?.activeAlert;

    return Scaffold(
      appBar: AppBar(title: const Text('Engine health')),
      body: RefreshIndicator(
        onRefresh: state.refresh,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (health != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(CtColors.statusIcon(health.status),
                          size: 56, color: CtColors.statusColor(health.status)),
                      const SizedBox(height: 8),
                      Text(CtColors.statusLabel(health.status),
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: CtColors.statusColor(health.status))),
                      const SizedBox(height: 6),
                      Text(health.message, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _chip('Drift',
                              '${health.driftPct >= 0 ? '+' : ''}${health.driftPct.toStringAsFixed(1)}%'),
                          _chip('Trips analysed', '${health.tripsAnalyzed}'),
                          _chip('Data',
                              health.fuelBacked ? 'Fuel-backed' : 'Model estimate'),
                          if (health.idleRising) _chip('Idle CO₂', 'Rising'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (active != null && active.servicedAt == null)
                Card(
                  color: CtColors.brandLight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Just got it serviced?',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        const Text(
                            'Mark it below — the next trips will verify your '
                            'emissions returned to baseline.',
                            style: TextStyle(fontSize: 12.5)),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          icon: const Icon(Icons.build),
                          label: const Text('Mark as serviced'),
                          onPressed: () async {
                            await state.markServiced();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Noted — watching for recovery on your next trips.')));
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text('History',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            if (state.alerts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No alerts yet — that\'s a good thing.',
                    style: TextStyle(color: Colors.black54)),
              ),
            ...state.alerts.map((a) => ListTile(
                  leading: Icon(
                    a.level == 'recovered'
                        ? Icons.task_alt
                        : CtColors.statusIcon(a.level),
                    color: a.level == 'recovered'
                        ? CtColors.ok
                        : CtColors.statusColor(a.level),
                  ),
                  title: Text(
                      a.level == 'recovered'
                          ? 'Recovered'
                          : CtColors.statusLabel(a.level),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                      '${DateFormat('d MMM y').format(a.createdAt.toLocal())} — ${a.message}',
                      style: const TextStyle(fontSize: 12)),
                )),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value) => Chip(
        label: Text('$label: $value', style: const TextStyle(fontSize: 12)),
        visualDensity: VisualDensity.compact,
      );
}
