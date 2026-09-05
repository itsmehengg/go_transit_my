import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../alerts/peak_hour_popup_service.dart';
import '../analytics/transport_analytics_screen.dart';
import '../home/home_screen.dart';
import '../profile/personalisation_service.dart';
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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPeakHourPopupIfNeeded();
    });
  }

  Future<void> _showPeakHourPopupIfNeeded() async {
    final notificationsEnabled =
        PersonalisationService.instance.notificationsEnabled;
    if (!notificationsEnabled) return;

    final alert = await PeakHourPopupService.instance.alertToShowNow();

    if (!mounted || alert == null) return;

    await _showPeakHourDialog(alert);
  }

  Future<void> _showPeakHourDialog(PeakHourPopupAlert alert) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(
            Icons.notifications_active_rounded,
            color: AppColors.primary,
            size: 34,
          ),
          title: Text(alert.title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(alert.message),
                const SizedBox(height: 14),
                _PeakInfoTile(
                  icon: Icons.schedule_rounded,
                  label: 'Expected peak window',
                  value: alert.peakWindow,
                ),
                const SizedBox(height: 8),
                _PeakInfoTile(
                  icon: Icons.groups_rounded,
                  label: 'Highest expected crowd',
                  value: '${alert.highestCrowdPercent}%',
                ),
                const SizedBox(height: 14),
                const Text(
                  'Stations to watch',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                for (final station in alert.stations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CrowdedStationRow(station: station),
                  ),
                const SizedBox(height: 6),
                Text(
                  alert.advice,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  alert.sourceLabel,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _index = 3);
              },
              icon: const Icon(Icons.analytics_rounded),
              label: const Text('View Analytics'),
            ),
          ],
        );
      },
    );
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

class _PeakInfoTile extends StatelessWidget {
  const _PeakInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _CrowdedStationRow extends StatelessWidget {
  const _CrowdedStationRow({required this.station});

  final CrowdedStationPrediction station;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.warning.withOpacity(0.16),
          child: Text(
            '${station.crowdPercent}%',
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                station.station,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              Text(
                station.reason,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
