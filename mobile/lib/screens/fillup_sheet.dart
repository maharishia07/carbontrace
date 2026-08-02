import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

/// Bottom sheet for logging a refuel.
///
/// The odometer is auto-captured from the virtual odometer (set once, then
/// advanced by every GPS trip) — litres is the only figure to confirm.
/// With a connected car linked, even this sheet is unnecessary: the sync
/// pulls fuel data with zero taps.
class FillUpSheet extends StatefulWidget {
  const FillUpSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => const FillUpSheet(),
      );

  @override
  State<FillUpSheet> createState() => _FillUpSheetState();
}

class _FillUpSheetState extends State<FillUpSheet> {
  final _litres = TextEditingController();
  final _odo = TextEditingController();
  bool _fullTank = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final v = context.read<AppState>().vehicle;
    if (v != null && v.odometerKm > 0) {
      _odo.text = v.odometerKm.toStringAsFixed(0);
    }
  }

  Future<void> _save() async {
    final litres = double.tryParse(_litres.text);
    final odo = double.tryParse(_odo.text);
    if (litres == null || litres <= 0) {
      setState(() => _error = 'Enter the litres filled');
      return;
    }
    if (odo == null || odo <= 0) {
      setState(() => _error = 'Enter the odometer reading (first time only)');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final state = context.read<AppState>();
      if (state.vehicle!.odometerKm <= 0) {
        await state.setOdometer(odo);
      }
      await state.logFillUp(litres: litres, odometerKm: odo, fullTank: _fullTank);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final autoOdo =
        (context.read<AppState>().vehicle?.odometerKm ?? 0) > 0;
    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.local_gas_station, color: CtColors.brand),
            SizedBox(width: 8),
            Text('Log fill-up',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          Text(
            autoOdo
                ? 'Odometer auto-captured from your trips — correct it only if it drifted.'
                : 'First fill-up: enter your dashboard odometer once. From then on it\'s automatic.',
            style: const TextStyle(fontSize: 12.5, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!,
                  style: const TextStyle(color: CtColors.alert, fontSize: 12.5)),
            ),
          TextField(
            controller: _litres,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Litres filled', prefixIcon: Icon(Icons.water_drop)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _odo,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Odometer (km)',
              prefixIcon: const Icon(Icons.speed),
              helperText: autoOdo ? 'auto-filled' : null,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Filled to full tank'),
            subtitle: const Text(
                'Full-to-full fill-ups give exact measured fuel economy',
                style: TextStyle(fontSize: 11.5)),
            value: _fullTank,
            onChanged: (v) => setState(() => _fullTank = v),
          ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.check),
              label: Text(_busy ? 'Saving…' : 'Save fill-up'),
              onPressed: _busy ? null : _save,
            ),
          ),
        ],
      ),
    );
  }
}
