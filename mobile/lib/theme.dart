import 'package:flutter/material.dart';

/// CarbonTrace design system — modern web-app feel: soft surfaces, rounded
/// cards, one strong gradient, restrained ink-first typography.
class CtColors {
  // brand
  static const brand = Color(0xFF0F5132);       // deep emerald
  static const brandBright = Color(0xFF10B981); // emerald 500
  static const brandLight = Color(0xFFE7F6EF);

  // surfaces & ink (slate scale, like tailwind web apps)
  static const bg = Color(0xFFF6F8F7);
  static const card = Colors.white;
  static const ink = Color(0xFF0F172A);
  static const inkSecondary = Color(0xFF64748B);
  static const inkFaint = Color(0xFF94A3B8);
  static const divider = Color(0xFFE2E8F0);

  // status palette (CVD-validated; always icon + label, never color alone)
  static const ok = Color(0xFF0B8A5C);
  static const watch = Color(0xFF9A6700);
  static const alert = Color(0xFFD3305A);
  static const pucRisk = Color(0xFF7C4DCC);

  static const chartLine = Color(0xFF0F5132);
  static const baselineBand = Color(0x2410B981);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B3D2E), Color(0xFF0F5132), Color(0xFF12805C)],
  );

  static Color statusColor(String status) => switch (status) {
        'ok' => ok,
        'watch' => watch,
        'alert' => alert,
        'puc_risk' => pucRisk,
        _ => inkSecondary,
      };

  static IconData statusIcon(String status) => switch (status) {
        'ok' => Icons.check_circle_rounded,
        'watch' => Icons.visibility_rounded,
        'alert' => Icons.build_circle_rounded,
        'puc_risk' => Icons.error_rounded,
        _ => Icons.hourglass_top_rounded, // learning
      };

  static String statusLabel(String status) => switch (status) {
        'ok' => 'Healthy',
        'watch' => 'Watching',
        'alert' => 'Service recommended',
        'puc_risk' => 'PUC failure risk',
        _ => 'Learning baseline',
      };
}

/// Soft drop shadow used by every card — barely-there, like web `shadow-sm`.
List<BoxShadow> ctShadow = [
  BoxShadow(
    color: const Color(0xFF0F172A).withValues(alpha: 0.06),
    blurRadius: 16,
    offset: const Offset(0, 4),
  ),
];

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: CtColors.brand,
    surface: CtColors.bg,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: CtColors.bg,
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
          fontWeight: FontWeight.w800, color: CtColors.ink, letterSpacing: -0.5),
      titleLarge: TextStyle(
          fontWeight: FontWeight.w700, color: CtColors.ink, letterSpacing: -0.3),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, color: CtColors.ink),
      bodyMedium: TextStyle(color: CtColors.ink, height: 1.35),
      bodySmall: TextStyle(color: CtColors.inkSecondary, height: 1.35),
      labelSmall: TextStyle(
          color: CtColors.inkFaint,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: CtColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
          color: CtColors.ink,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: CtColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: CtColors.divider, width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CtColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CtColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CtColors.brandBright, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CtColors.brand,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: CtColors.brand,
      foregroundColor: Colors.white,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      height: 68,
      indicatorColor: CtColors.brandLight,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? CtColors.brand
              : CtColors.inkFaint)),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? CtColors.brand
              : CtColors.inkFaint)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: CtColors.bg,
      side: const BorderSide(color: CtColors.divider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: const TextStyle(fontSize: 12, color: CtColors.ink),
    ),
    dividerTheme: const DividerThemeData(color: CtColors.divider, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: CtColors.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );
}

/// Small rounded status pill: icon + label, tinted by status.
class StatusPill extends StatelessWidget {
  final String status;
  final bool onDark;

  const StatusPill({super.key, required this.status, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final color = CtColors.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.14)
            : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: onDark
                ? Colors.white.withValues(alpha: 0.25)
                : color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CtColors.statusIcon(status),
              size: 15, color: onDark ? Colors.white : color),
          const SizedBox(width: 6),
          Text(
            CtColors.statusLabel(status),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: onDark ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section label like web apps use above card groups.
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11)),
    );
  }
}
