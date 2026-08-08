import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/demo_data.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 64, 20, 28),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Color(0xFFDDEBFF),
                  child: Icon(Icons.person, size: 38, color: AppColors.primary),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yong Wen',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Premium User',
                      style: TextStyle(color: Color(0xFFDDEBFF)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const _ProfileRow(Icons.insights_rounded, 'My Stats'),
                _ProfileRow(
                  Icons.favorite_rounded,
                  'Favourite Stations',
                  subtitle: stations.length.toString(),
                ),
                const _ProfileRow(Icons.route_rounded, 'Favourite Routes'),
                const _ProfileRow(Icons.history_rounded, 'Recent Searches'),
                const _ProfileRow(
                  Icons.notifications_rounded,
                  'Notification Settings',
                ),
                const _ProfileRow(
                  Icons.language_rounded,
                  'Language',
                  subtitle: 'English / Bahasa Melayu',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(
                    Icons.dark_mode_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Dark Mode',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Stored locally with SharedPreferences later',
                  ),
                  value: false,
                  onChanged: (_) {},
                ),
                const Divider(),
                const _ProfileRow(Icons.help_outline_rounded, 'Help & Support'),
                const _ProfileRow(Icons.logout_rounded, 'Logout', danger: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow(
    this.icon,
    this.label, {
    this.subtitle,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.primary;
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: danger ? color : null,
          ),
        ),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
