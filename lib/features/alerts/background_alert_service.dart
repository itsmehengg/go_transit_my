import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import 'local_alert_notification_service.dart';
import 'transport_alert_service.dart';

const _backgroundTaskName = 'check_service_alerts';
const _backgroundTaskUniqueName = 'module4_service_alert_check';
const _notificationsPreferenceKey = 'module1_notifications';
const _notifiedAlertKeysPreferenceKey = 'module4_notified_alert_keys';
const _supabaseUrl = 'https://zadpajrsmgjuniryqcqp.supabase.co';
const _supabasePublishableKey =
    'sb_publishable_3AUx7p1OFYZSe4Hvxifr_g_9I0cQfYR';

@pragma('vm:entry-point')
void backgroundAlertCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _backgroundTaskName) return true;

    DartPluginRegistrant.ensureInitialized();

    final preferences = await SharedPreferences.getInstance();
    final enabled = preferences.getBool(_notificationsPreferenceKey) ?? true;
    if (!enabled) return true;

    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabasePublishableKey,
    );

    final alerts = await TransportAlertService().fetchAlerts();
    final storedKeys = preferences
            .getStringList(_notifiedAlertKeysPreferenceKey)
            ?.toSet() ??
        <String>{};

    if (storedKeys.isEmpty) {
      await preferences.setStringList(
        _notifiedAlertKeysPreferenceKey,
        alerts.map(_alertKey).take(100).toList(),
      );
      return true;
    }

    final newAlerts = alerts
        .where((alert) => !storedKeys.contains(_alertKey(alert)))
        .toList()
        .reversed
        .toList();

    if (newAlerts.isNotEmpty) {
      await LocalAlertNotificationService.instance.initialise();

      for (final alert in newAlerts.take(5)) {
        final key = _alertKey(alert);
        await LocalAlertNotificationService.instance.showServiceAlert(
          id: key.hashCode & 0x7fffffff,
          title: alert.title,
          message: alert.message,
          payload: alert.id,
        );
        storedKeys.add(key);
      }

      final latestKeys = <String>{
        ...alerts.map(_alertKey),
        ...storedKeys,
      }.take(100).toList();

      await preferences.setStringList(
        _notifiedAlertKeysPreferenceKey,
        latestKeys,
      );
    }

    return true;
  });
}

String _alertKey(TransportAlert alert) {
  if (alert.id.trim().isNotEmpty) return alert.id.trim();
  return '${alert.title}|${alert.message}|${alert.createdAt?.toIso8601String() ?? ''}';
}

class BackgroundAlertService {
  BackgroundAlertService._();

  static final BackgroundAlertService instance = BackgroundAlertService._();

  Future<void> initialise({required bool enabled}) async {
    await Workmanager().initialize(backgroundAlertCallbackDispatcher);
    await LocalAlertNotificationService.instance.initialise(
      requestPermission: enabled,
    );
    await setEnabled(enabled);
  }

  Future<void> setEnabled(bool enabled) async {
    if (!enabled) {
      await Workmanager().cancelByUniqueName(_backgroundTaskUniqueName);
      return;
    }

    await _seedExistingAlertsIfNeeded();

    final scheduled =
        await Workmanager().isScheduledByUniqueName(_backgroundTaskUniqueName);
    if (scheduled) return;

    await Workmanager().registerPeriodicTask(
      _backgroundTaskUniqueName,
      _backgroundTaskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  Future<void> _seedExistingAlertsIfNeeded() async {
    final preferences = await SharedPreferences.getInstance();
    final existing =
        preferences.getStringList(_notifiedAlertKeysPreferenceKey) ?? <String>[];
    if (existing.isNotEmpty) return;

    try {
      final alerts = await TransportAlertService().fetchAlerts();
      await preferences.setStringList(
        _notifiedAlertKeysPreferenceKey,
        alerts.map(_alertKey).take(100).toList(),
      );
    } catch (_) {}
  }
}
