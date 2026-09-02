import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalAlertNotificationService {
  LocalAlertNotificationService._();

  static final LocalAlertNotificationService instance =
      LocalAlertNotificationService._();

  static const channelId = 'service_alerts';
  static const channelName = 'Service Alerts';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialise({bool requestPermission = false}) async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(settings: settings);

    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: 'Public transport service alert notifications',
      importance: Importance.high,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(channel);

    if (requestPermission) {
      await android?.requestNotificationsPermission();
    }
  }

  Future<void> showServiceAlert({
    required int id,
    required String title,
    required String message,
    required String payload,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Public transport service alert notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await _plugin.show(
      id: id,
      title: title,
      body: message,
      notificationDetails: details,
      payload: payload,
    );
  }
}
