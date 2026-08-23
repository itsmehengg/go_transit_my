import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/demo_data.dart';
import '../profile/profile_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _profileService = ProfileService();
  Timer? _clockTimer;
  DateTime _now = DateTime.now();
  String? _fullName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final profile = await _profileService.getCurrentProfile();
    final metadataName =
        _profileService.currentUser?.userMetadata?['full_name'] as String?;

    if (!mounted) return;
    setState(() {
      _fullName =
          profile?['full_name'] as String? ?? metadataName ?? 'GoTransit User';
    });
  }

  String get _greeting {
    final hour = _now.hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 18) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  String get _timeLabel {
    final hour = _now.hour;
    final minute = _now.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _fullName ?? 'Loading...';

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_greeting $_timeLabel',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                      Text(
                        '$displayName 👋',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_outlined),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(
                hintText: 'Where do you want to go?',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: AppColors.line),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const SectionTitle('Nearby Station', trailing: 'See all'),
            const SizedBox(height: 10),
            AppCard(
              color: AppColors.primary,
              child: Stack(
                children: [
                  Positioned(
                    right: -40,
                    top: -45,
                    child: Icon(
                      Icons.train_rounded,
                      size: 170,
                      color: Colors.white.withValues(alpha: .08),
                    ),
                  ),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KL Sentral',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '300 m • MRT • LRT • KTM',
                        style: TextStyle(color: Color(0xFFD8E7FF)),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          StatusChip('10:00 AM', color: Colors.white),
                          SizedBox(width: 8),
                          StatusChip('Live', color: AppColors.success),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const SectionTitle('Quick Access'),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: const [
                _QuickAccess(icon: Icons.route_rounded, label: 'Routes'),
                _QuickAccess(icon: Icons.train_rounded, label: 'Arrival'),
                _QuickAccess(
                  icon: Icons.location_on_rounded,
                  label: 'Stations',
                ),
                _QuickAccess(
                  icon: Icons.warning_amber_rounded,
                  label: 'Alerts',
                ),
              ],
            ),
            const SizedBox(height: 28),
            AppCard(
              color: const Color(0xFFECFDF5),
              child: Row(
                children: [
                  const TransportIcon(
                    icon: Icons.train_rounded,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Update',
                          style: TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text('MRT Kajang Line arriving in 2 mins • Platform 1'),
                        Text(
                          'Last updated: 10:40 AM',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.green.shade800,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const SectionTitle('Recent Searches'),
            const SizedBox(height: 10),
            ...stations
                .take(3)
                .map(
                  (s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_rounded),
                    title: Text(
                      '${s.name} → KLCC',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(s.location),
                    trailing: Text(s.distance),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccess extends StatelessWidget {
  const _QuickAccess({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
