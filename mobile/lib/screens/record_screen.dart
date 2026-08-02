import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

/// Manual trip recording + auto-record status.
///
/// In normal use trips start themselves (car Bluetooth / motion). This
/// screen exists for the demo, for testing, and as the visible state of
/// the recorder.
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // repaint every second while recording so duration/point count tick up
    _ticker = Timer.periodic(
        const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final rec = state.recorder;

    return Scaffold(
      appBar: AppBar(title: const Text('Record')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: state.autoRecordEnabled
                  ? CtColors.brandLight
                  : Colors.grey.shade100,
              child: SwitchListTile(
                title: const Text('Auto-record trips'),
                subtitle: const Text(
                    'Starts recording when your phone connects to the car\'s '
                    'Bluetooth or driving is detected'),
                value: state.autoRecordEnabled,
                onChanged: (v) => state.setAutoRecord(v),
              ),
            ),
            const SizedBox(height: 24),
            Icon(
              rec.recording ? Icons.gps_fixed : Icons.gps_off,
              size: 72,
              color: rec.recording ? CtColors.ok : Colors.black26,
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                rec.recording
                    ? 'Recording — ${rec.pointCount} points'
                    : 'Not recording',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            if (rec.recording && rec.startedAt != null)
              Center(
                child: Text(
                  'Started ${TimeOfDay.fromDateTime(rec.startedAt!).format(context)}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: rec.recording ? CtColors.alert : CtColors.brand,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: Icon(rec.recording ? Icons.stop : Icons.play_arrow),
              label: Text(rec.recording ? 'Stop & save trip' : 'Start recording'),
              onPressed: () async {
                if (rec.recording) {
                  await rec.stop();
                } else {
                  await rec.start();
                  if (!rec.recording && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Location permission needed to record trips')));
                  }
                }
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Trips shorter than ~200 m are discarded. Recording stops itself '
              'after 5 minutes parked.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
