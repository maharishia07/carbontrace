import 'package:flutter/material.dart';

/// Brand + status colors.
///
/// Status palette validated for color-vision deficiency (light & dark
/// surfaces). Statuses are NEVER shown by color alone — always icon + label.
class CtColors {
  static const brand = Color(0xFF1B5E20);
  static const brandLight = Color(0xFFF1F8E9);

  // status palette (CVD-validated)
  static const ok = Color(0xFF0B8A5C);
  static const watch = Color(0xFF9A6700);
  static const alert = Color(0xFFD3305A);
  static const pucRisk = Color(0xFF7C4DCC);

  static const chartLine = Color(0xFF1B5E20);
  static const baselineBand = Color(0x331B5E20);

  static Color statusColor(String status) => switch (status) {
        'ok' => ok,
        'watch' => watch,
        'alert' => alert,
        'puc_risk' => pucRisk,
        _ => Colors.blueGrey,
      };

  static IconData statusIcon(String status) => switch (status) {
        'ok' => Icons.check_circle,
        'watch' => Icons.remove_red_eye,
        'alert' => Icons.build_circle,
        'puc_risk' => Icons.error,
        _ => Icons.hourglass_top, // learning
      };

  static String statusLabel(String status) => switch (status) {
        'ok' => 'Healthy',
        'watch' => 'Watching',
        'alert' => 'Service recommended',
        'puc_risk' => 'PUC failure risk',
        _ => 'Learning baseline',
      };
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: CtColors.brand);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: CtColors.brand,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
  );
}
