import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      CtColors.statusColor(health.status)
                          .withValues(alpha: 0.12),
                      CtColors.statusColor(health.status)
                          .withValues(alpha: 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: CtColors.statusColor(health.status)
                          .withValues(alpha: 0.30)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: ctShadow,
                      ),
                      child: Icon(CtColors.statusIcon(health.status),
                          size: 40,
                          color: CtColors.statusColor(health.status)),
                    ),
                    const SizedBox(height: 12),
                    Text(CtColors.statusLabel(health.status),
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: CtColors.statusColor(health.status))),
                    const SizedBox(height: 6),
                    Text(health.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, height: 1.4)),
                    const SizedBox(height: 14),
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
            if (state.economy != null) _EconomyCard(economy: state.economy!),
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

class _EconomyCard extends StatelessWidget {
  final Economy economy;
  const _EconomyCard({required this.economy});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.local_gas_station,
                  size: 18, color: CtColors.brand),
              const SizedBox(width: 6),
              const Text('Measured fuel economy',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const Spacer(),
              if (economy.calibratedAt != null)
                const Tooltip(
                  message: 'Estimates are anchored to your real fuel data',
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.verified, size: 16, color: CtColors.ok),
                    SizedBox(width: 3),
                    Text('Fuel-anchored',
                        style: TextStyle(
                            fontSize: 12,
                            color: CtColors.ok,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
            const SizedBox(height: 6),
            if (economy.segments.isEmpty)
              Text(
                economy.fillups == 0
                    ? 'Log your fill-ups (⛽ button on the dashboard) — two full '
                        'tanks give your first measured reading, and all estimates '
                        'get calibrated against real fuel burned.'
                    : 'One more full-tank fill-up and your first measured '
                        'economy reading appears.',
                style: const TextStyle(fontSize: 12.5, color: Colors.black54),
              )
            else ...[
              ...economy.segments.reversed.take(4).map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                            '${DateFormat('d MMM').format(s.startAt.toLocal())} – '
                            '${DateFormat('d MMM').format(s.endAt.toLocal())}  ·  '
                            '${s.km.toStringAsFixed(0)} km',
                            style: const TextStyle(fontSize: 12.5)),
                      ),
                      Text(
                          '${s.lPer100km.toStringAsFixed(1)} L/100km  ·  '
                          '${s.measuredGpkm.toStringAsFixed(0)} g/km',
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ]),
                  )),
              if (economy.calibratedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Model calibration: ×${economy.calibrationFactor.toStringAsFixed(2)} '
                    '(measured ÷ modelled). Trip estimates use this factor.',
                    style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
