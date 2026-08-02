import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

/// Manual trip recording + auto-record status.
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: state.autoRecordEnabled
                  ? CtColors.brandLight
                  : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: state.autoRecordEnabled
                      ? CtColors.brandBright.withValues(alpha: 0.4)
                      : CtColors.divider),
            ),
            child: SwitchListTile(
              title: const Text('Auto-record trips',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              subtitle: const Text(
                  'Starts when your phone connects to the car\'s Bluetooth or driving is detected',
                  style: TextStyle(fontSize: 12.5)),
              activeThumbColor: CtColors.brand,
              value: state.autoRecordEnabled,
              onChanged: (v) => state.setAutoRecord(v),
            ),
          ),
          const SizedBox(height: 44),
          Center(
            child: GestureDetector(
              onTap: () async {
                if (rec.recording) {
                  await rec.stop();
                } else {
                  await rec.start();
                  if (!rec.recording && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text('Location permission needed to record trips')));
                  }
                }
                setState(() {});
              },
              child: Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: rec.recording
                      ? const LinearGradient(
                          colors: [Color(0xFFBE123C), Color(0xFFE11D48)])
                      : CtColors.heroGradient,
                  boxShadow: [
                    BoxShadow(
                      color: (rec.recording
                              ? const Color(0xFFE11D48)
                              : CtColors.brandBright)
                          .withValues(alpha: 0.35),
                      blurRadius: 34,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                        rec.recording
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 52),
                    Text(rec.recording ? 'STOP & SAVE' : 'START TRIP',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Column(children: [
              Text(
                rec.recording
                    ? 'Recording — ${rec.pointCount} GPS points'
                    : 'Not recording',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: CtColors.ink),
              ),
              if (rec.recording && rec.startedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Started ${TimeOfDay.fromDateTime(rec.startedAt!).format(context)}',
                    style: const TextStyle(color: CtColors.inkSecondary),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 28),
          const Center(
            child: Text(
              'Trips shorter than ~200 m are discarded.\nRecording stops itself after 5 minutes parked.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: CtColors.inkFaint, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
