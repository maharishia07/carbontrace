import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'screens/dashboard_screen.dart';
import 'screens/health_screen.dart';
import 'screens/record_screen.dart';
import 'screens/trips_screen.dart';
import 'screens/vehicle_setup_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  state.init();
  runApp(
    ChangeNotifierProvider.value(value: state, child: const CarbonTraceApp()),
  );
}

class CarbonTraceApp extends StatelessWidget {
  const CarbonTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CarbonTrace',
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      home: const RootScreen(),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.vehicle == null) {
      return const VehicleSetupScreen();
    }

    const screens = [
      DashboardScreen(),
      TripsScreen(),
      RecordScreen(),
      HealthScreen(),
    ];
    return Scaffold(
      body: screens[_tab],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard_rounded),
                label: 'Dashboard'),
            NavigationDestination(
                icon: Icon(Icons.route_outlined),
                selectedIcon: Icon(Icons.route_rounded),
                label: 'Trips'),
            NavigationDestination(
                icon: Icon(Icons.radio_button_checked),
                label: 'Record'),
            NavigationDestination(
                icon: Icon(Icons.monitor_heart_outlined),
                selectedIcon: Icon(Icons.monitor_heart_rounded),
                label: 'Health'),
          ],
        ),
      ),
    );
  }
}
