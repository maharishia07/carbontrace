import 'package:flutter/material.dart';

/// Hero-number tile: one value, one label, optional caption.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;

  const StatTile(
      {super.key, required this.label, required this.value, this.caption});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 0.6,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700)),
              if (caption != null) ...[
                const SizedBox(height: 2),
                Text(caption!,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
