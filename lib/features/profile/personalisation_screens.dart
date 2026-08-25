import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import 'personalisation_service.dart';

class FavouriteStationsScreen extends StatelessWidget {
  const FavouriteStationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = PersonalisationService.instance;
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Favourite Stations')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddItemDialog(
            context,
            title: 'Add Favourite Station',
            hint: 'e.g. KL Sentral',
            onAdd: service.addFavouriteStation,
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add'),
        ),
        body: _StringListBody(
          items: service.favouriteStations,
          emptyIcon: Icons.favorite_border_rounded,
          emptyTitle: 'No favourite stations yet',
          emptyMessage: 'Save stations you use often for faster access.',
          leadingIcon: Icons.train_rounded,
          onDelete: service.removeFavouriteStation,
        ),
      ),
    );
  }
}

class FavouriteRoutesScreen extends StatelessWidget {
  const FavouriteRoutesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = PersonalisationService.instance;
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Favourite Routes')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddItemDialog(
            context,
            title: 'Add Favourite Route',
            hint: 'e.g. KL Sentral → KLCC',
            onAdd: service.addFavouriteRoute,
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add'),
        ),
        body: _StringListBody(
          items: service.favouriteRoutes,
          emptyIcon: Icons.route_outlined,
          emptyTitle: 'No favourite routes yet',
          emptyMessage: 'Saved routes will appear here.',
          leadingIcon: Icons.route_rounded,
          onDelete: service.removeFavouriteRoute,
        ),
      ),
    );
  }
}

class RecentSearchesScreen extends StatelessWidget {
  const RecentSearchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = PersonalisationService.instance;
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Recent Searches'),
          actions: [
            if (service.recentSearches.isNotEmpty)
              TextButton(
                onPressed: () => _confirmClear(context, service),
                child: const Text('Clear'),
              ),
          ],
        ),
        body: _StringListBody(
          items: service.recentSearches,
          emptyIcon: Icons.history_rounded,
          emptyTitle: 'No recent searches',
          emptyMessage: 'Your latest route searches will appear here.',
          leadingIcon: Icons.history_rounded,
        ),
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    PersonalisationService service,
  ) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear recent searches?'),
        content: const Text('This removes all locally stored recent searches.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (shouldClear == true) await service.clearRecentSearches();
  }
}

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = PersonalisationService.instance;
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Notification Settings')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AppCard(
              padding: EdgeInsets.zero,
              child: SwitchListTile(
                value: service.notificationsEnabled,
                onChanged: service.setNotificationsEnabled,
                secondary: const Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'App notifications',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Allow transport alerts and important app updates.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This preference is saved on this device.',
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = PersonalisationService.instance;
    const languages = ['English', 'Bahasa Melayu', '中文'];
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Language')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final language in languages)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: RadioListTile<String>(
                    value: language,
                    groupValue: service.language,
                    onChanged: (value) {
                      if (value != null) service.setLanguage(value);
                    },
                    title: Text(
                      language,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PreferredTransportScreen extends StatelessWidget {
  const PreferredTransportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = PersonalisationService.instance;
    const modes = ['All', 'MRT', 'LRT', 'Bus', 'KTM'];
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Preferred Transport')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Choose the transport mode you prefer to see first in journey planning.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            for (final mode in modes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: RadioListTile<String>(
                    value: mode,
                    groupValue: service.preferredTransport,
                    onChanged: (value) {
                      if (value != null) service.setPreferredTransport(value);
                    },
                    title: Text(
                      mode,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    secondary: Icon(
                      mode == 'Bus'
                          ? Icons.directions_bus_rounded
                          : Icons.train_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StringListBody extends StatelessWidget {
  const _StringListBody({
    required this.items,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.leadingIcon,
    this.onDelete,
  });

  final List<String> items;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final IconData leadingIcon;
  final Future<void> Function(String)? onDelete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(emptyIcon, size: 72, color: AppColors.muted),
              const SizedBox(height: 18),
              Text(
                emptyTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return AppCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(leadingIcon, color: AppColors.primary),
            title: Text(
              item,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            trailing: onDelete == null
                ? null
                : IconButton(
                    tooltip: 'Remove',
                    onPressed: () => onDelete!(item),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
          ),
        );
      },
    );
  }
}

Future<void> _showAddItemDialog(
  BuildContext context, {
  required String title,
  required String hint,
  required Future<void> Function(String) onAdd,
}) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (value != null) await onAdd(value);
}
