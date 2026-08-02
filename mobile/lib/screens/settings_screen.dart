import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _server;

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: context.read<AppState>().api.baseUrl);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _server,
            decoration: InputDecoration(
              labelText: 'Server URL',
              helperText:
                  'Emulator → http://10.0.2.2:8000 · Real phone → your PC\'s LAN IP',
              suffixIcon: IconButton(
                icon: const Icon(Icons.save),
                onPressed: () async {
                  await state.setServer(_server.text);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Server saved')));
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Auto-record trips'),
            subtitle: const Text('Start recording on car Bluetooth / driving'),
            value: state.autoRecordEnabled,
            onChanged: (v) => state.setAutoRecord(v),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Switch vehicle'),
            subtitle: const Text('Go back to the vehicle list'),
            onTap: () {
              context.read<AppState>().clearVehicle();
              Navigator.popUntil(context, (r) => r.isFirst);
            },
          ),
          ListTile(
            leading: const Icon(Icons.directions_car_filled),
            title: const Text('Sync connected car (demo)'),
            subtitle: const Text(
                'Pulls odometer + fuel consumed automatically, zero taps at the '
                'pump. Uses the simulated connector until a car account is linked.'),
            onTap: () async {
              final state = context.read<AppState>();
              try {
                await state.syncConnectedCar();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Connected-car data synced')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Sync failed: set the odometer once first '
                          '(log a fill-up). $e')));
                }
              }
            },
          ),
          const Divider(height: 32),
          const ListTile(
            leading: Icon(Icons.battery_saver),
            title: Text('Battery optimisation'),
            subtitle: Text(
                'On Xiaomi / Oppo / Vivo / Realme phones, set CarbonTrace to '
                '"No restrictions" in battery settings, or auto-recording '
                'will be killed in the background.'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('About the numbers'),
            subtitle: Text(
                'CO₂ figures are estimates from your driving profile and your '
                'car\'s certified emission factors (±15%). Drift detection '
                'compares your car only against its own baseline, which is far '
                'more reliable than the absolute value. CarbonTrace does not '
                'replace PUC testing — it helps you pass it first time.'),
          ),
        ],
      ),
    );
  }
}
