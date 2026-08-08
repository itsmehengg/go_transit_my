import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_screens.dart';
import 'features/shell/app_shell.dart';

class GoTransitApp extends StatelessWidget {
  const GoTransitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoTransit MY',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      initialRoute: SplashScreen.routeName,
      routes: {
        SplashScreen.routeName: (_) => const SplashScreen(),
        OnboardingScreen.routeName: (_) => const OnboardingScreen(),
        LoginScreen.routeName: (_) => const LoginScreen(),
        RegisterScreen.routeName: (_) => const RegisterScreen(),
        AppShell.routeName: (_) => const AppShell(),
      },
    );
  }
}
