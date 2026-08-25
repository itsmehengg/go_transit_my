import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_screens.dart';
import 'features/profile/personalisation_service.dart';
import 'features/shell/app_shell.dart';

class GoTransitApp extends StatefulWidget {
  const GoTransitApp({super.key});

  @override
  State<GoTransitApp> createState() => _GoTransitAppState();
}

class _GoTransitAppState extends State<GoTransitApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event != AuthChangeEvent.passwordRecovery) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigatorKey.currentState?.pushNamedAndRemoveUntil(
          ResetPasswordScreen.routeName,
          (_) => false,
        );
      });
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final personalisation = PersonalisationService.instance;
    return AnimatedBuilder(
      animation: personalisation,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'GoTransit MY',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: personalisation.darkMode ? ThemeMode.dark : ThemeMode.light,
          initialRoute: SplashScreen.routeName,
          routes: {
            SplashScreen.routeName: (_) => const SplashScreen(),
            OnboardingScreen.routeName: (_) => const OnboardingScreen(),
            LoginScreen.routeName: (_) => const LoginScreen(),
            RegisterScreen.routeName: (_) => const RegisterScreen(),
            ForgotPasswordScreen.routeName: (_) => const ForgotPasswordScreen(),
            ResetPasswordScreen.routeName: (_) => const ResetPasswordScreen(),
            AppShell.routeName: (_) => const AppShell(),
          },
        );
      },
    );
  }
}
