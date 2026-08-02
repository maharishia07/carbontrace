import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/trend_chart.dart';
import 'fillup_sheet.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dash = state.dashboard;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.local_gas_station_rounded),
        label: const Text('Fill-up',
            style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => FillUpSheet.show(context),
      ),
      body: RefreshIndicator(
        color: CtColors.brand,
        onRefresh: state.refresh,
        child: dash == null
            ? ListView(children: const [
                SizedBox(height: 240),
                Center(child: CircularProgressIndicator(color: CtColors.brand)),
              ])
            : ListView(
                padding: EdgeInsets.zero,
                children: [
                  _HeroHeader(state: state),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (state.error != null) _ErrorCard(text: state.error!),
                        if (dash.refuelHintAt != null) const _RefuelCard(),
                        if (dash.activeAlert != null)
                          _AlertCard(
                              level: dash.activeAlert!.level,
                              message: dash.activeAlert!.message),
                        const SectionLabel('Emission trend'),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('CO₂ per km — recent trips',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontSize: 15)),
                                const SizedBox(height: 2),
                                Text(
                                  dash.health.baselines.containsKey('city')
                                      ? 'Shaded band = your car\'s normal range'
                                      : 'Baseline appears after ~8 trips per driving type',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 6),
                                TrendChart(
                                  points: dash.trend,
                                  baseline: dash.health.baselines['city'],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SectionLabel('This period'),
                        Row(children: [
                          _MiniStat(
                              label: 'Week',
                              value: '${dash.week.co2Kg}',
                              unit: 'kg CO₂',
                              caption:
                                  '${dash.week.distanceKm.toStringAsFixed(0)} km'),
                          const SizedBox(width: 10),
                          _MiniStat(
                              label: '30 days',
                              value: '${dash.month.co2Kg}',
                              unit: 'kg CO₂',
                              caption: dash.month.avgGpkm == null
                                  ? '—'
                                  : '${dash.month.avgGpkm!.toStringAsFixed(0)} g/km avg'),
                          const SizedBox(width: 10),
                          _MiniStat(
                              label: 'Trips',
                              value: '${dash.month.trips}',
                              unit: 'this month',
                              caption: dash.health.fuelBacked
                                  ? 'fuel-anchored ✓'
                                  : 'model estimate'),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final AppState state;
  const _HeroHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final dash = state.dashboard!;
    return Container(
      decoration: const BoxDecoration(
        gradient: CtColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 14, 12, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_car_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(state.vehicle?.name ?? 'CarbonTrace',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3)),
                    Text(
                      '${state.vehicle?.make ?? ''} ${state.vehicle?.model ?? ''}'
                          .trim(),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_rounded, color: Colors.white),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${dash.today.co2Kg}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      height: 0.95,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('kg CO₂',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    Text('today · ${dash.today.trips} trips',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12.5)),
                  ],
                ),
              ),
              const Spacer(),
              StatusPill(status: dash.health.status, onDark: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value, unit, caption;
  const _MiniStat(
      {required this.label,
      required this.value,
      required this.unit,
      required this.caption});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CtColors.divider),
          boxShadow: ctShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(fontSize: 10)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: CtColors.ink,
                    letterSpacing: -0.5)),
            Text(unit,
                style:
                    const TextStyle(fontSize: 11, color: CtColors.inkSecondary)),
            const SizedBox(height: 4),
            Text(caption,
                style: const TextStyle(
                    fontSize: 10.5,
                    color: CtColors.inkFaint,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final String level, message;
  const _AlertCard({required this.level, required this.message});

  @override
  Widget build(BuildContext context) {
    final color = CtColors.statusColor(level);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CtColors.statusIcon(level), color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(CtColors.statusLabel(level),
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
                const SizedBox(height: 3),
                Text(message,
                    style: const TextStyle(fontSize: 12.5, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RefuelCard extends StatelessWidget {
  const _RefuelCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_gas_station_rounded,
              color: CtColors.watch, size: 26),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Did you refuel?',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                SizedBox(height: 2),
                Text(
                    'Fuel-station stop detected. Odometer is captured — just confirm litres.',
                    style: TextStyle(fontSize: 12, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            onPressed: () => FillUpSheet.show(context),
            child: const Text('Log'),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String text;
  const _ErrorCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(children: [
        const Icon(Icons.wifi_off_rounded, color: Color(0xFFEA580C), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ]),
    );
  }
}
