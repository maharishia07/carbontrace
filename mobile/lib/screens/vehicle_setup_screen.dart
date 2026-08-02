import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'settings_screen.dart';

class VehicleSetupScreen extends StatefulWidget {
  const VehicleSetupScreen({super.key});

  @override
  State<VehicleSetupScreen> createState() => _VehicleSetupScreenState();
}

class _VehicleSetupScreenState extends State<VehicleSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController(text: '2021');
  String _classKey = 'hatch_petrol';
  List<VehicleClassOption> _catalog = [];
  List<Vehicle> _existing = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    try {
      final results =
          await Future.wait([state.api.catalog(), state.api.vehicles()]);
      setState(() {
        _catalog = results[0] as List<VehicleClassOption>;
        _existing = results[1] as List<Vehicle>;
        _error = null;
      });
    } catch (e) {
      setState(() => _error =
          'Cannot reach the server — check the URL in settings.\n$e');
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AppState>().registerVehicle(
            name: _name.text.trim(),
            make: _make.text.trim(),
            model: _model.text.trim(),
            year: int.tryParse(_year.text) ?? 2020,
            classKey: _classKey,
          );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('CarbonTrace — add your car'),
        actions: [
          IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!, style: const TextStyle(fontSize: 13))),
            ),
          if (_existing.isNotEmpty) ...[
            const Text('Your vehicles',
                style: TextStyle(fontWeight: FontWeight.w700)),
            ..._existing.map((v) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.directions_car,
                        color: CtColors.brand),
                    title: Text(v.name),
                    subtitle: Text('${v.make} ${v.model} · ${v.year}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: state.loading ? null : () => state.selectVehicle(v.id),
                  ),
                )),
            const Divider(height: 32),
            const Text('Or add a new one',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
          ],
          Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                      labelText: 'Nickname (e.g. My Swift)'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                Row(children: [
                  Expanded(
                      child: TextFormField(
                          controller: _make,
                          decoration:
                              const InputDecoration(labelText: 'Make'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextFormField(
                          controller: _model,
                          decoration:
                              const InputDecoration(labelText: 'Model'))),
                ]),
                TextFormField(
                  controller: _year,
                  decoration: const InputDecoration(labelText: 'Year'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _classKey,
                  decoration:
                      const InputDecoration(labelText: 'Vehicle class'),
                  items: (_catalog.isEmpty
                          ? [
                              VehicleClassOption.fromJson({
                                'key': 'hatch_petrol',
                                'label': 'Hatchback petrol (~1.2L)',
                                'fuel': 'petrol'
                              })
                            ]
                          : _catalog)
                      .map((c) => DropdownMenuItem(
                          value: c.key, child: Text(c.label)))
                      .toList(),
                  onChanged: (v) => setState(() => _classKey = v!),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Start tracking'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
