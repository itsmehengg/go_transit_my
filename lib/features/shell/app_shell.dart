import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../analytics/transport_analytics_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../routes/route_planner_screen.dart';
import '../stations/station_screens.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static const routeName = '/app';

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  String? _routeDestinationName;

  List<Widget> get _screens {
    return <Widget>[
      HomeScreen(
        onNavigateTab: _openTab,
        onSearchDestination: _openRouteWithDestination,
      ),
      RoutePlannerScreen(
        initialDestinationName: _routeDestinationName,
      ),
      const NearbyStationsScreen(),
      const TransportAnalyticsScreen(),
      const ProfileScreen(),
    ];
  }

  void _openTab(int index) {
    setState(() => _index = index);
  }

  void _openRouteWithDestination(String destination) {
    final clean = destination.trim();
    if (clean.isEmpty) return;

    setState(() {
      _routeDestinationName = clean;
      _index = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        indicatorColor: AppColors.primary.withOpacity(0.12),
        onDestinationSelected: (value) {
          setState(() => _index = value);
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Routes',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on),
            label: 'Stations',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
