import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'features/alerts/notification_service.dart';
import 'features/profile/personalisation_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await Supabase.initialize(
    url: 'https://zadpajrsmgjuniryqcqp.supabase.co',
    publishableKey: 'sb_publishable_3AUx7p1OFYZSe4Hvxifr_g_9I0cQfYR',
  );

  await PersonalisationService.instance.initialise();
  await NotificationService.instance.initialise(
    enabled: PersonalisationService.instance.notificationsEnabled,
  );

  runApp(const GoTransitApp());
}
