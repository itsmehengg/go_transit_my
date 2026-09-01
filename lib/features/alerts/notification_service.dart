import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static const topic = 'service-alerts';
  static const channelId = 'service_alerts';
  static const channelName = 'Service Alerts';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  Future<void> initialise({required bool enabled}) async {
    if (_initialised) {
      await setEnabled(enabled);
      return;
    }
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _local.initialize(settings: settings);
    const channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: 'Public transport service disruption notifications',
      importance: Importance.high,
    );
    final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(channel);
    await android?.requestNotificationsPermission();
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    _initialised = true;
    await setEnabled(enabled);
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await _messaging.subscribeToTopic(topic);
    } else {
      await _messaging.unsubscribeFromTopic(topic);
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['message']?.toString();
    if (title == null && body == null) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: 'Public transport service disruption notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _local.show(
      message.hashCode,
      title ?? 'GoTransit MY',
      body ?? 'New transport service alert',
      details,
      payload: message.data['alert_id']?.toString(),
    );
  }
}
