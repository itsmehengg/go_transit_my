import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../shell/app_shell.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  static const routeName = '/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary2, AppColors.primary],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Spacer(),
                const TransportIcon(
                  icon: Icons.directions_bus_rounded,
                  color: Colors.white,
                  size: 88,
                ),
                const SizedBox(height: 24),
                const Text(
                  'GoTransit MY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Smart Public Transport Tracker',
                  style: TextStyle(color: Color(0xFFDDEBFF)),
                ),
                const Spacer(),
                const LinearProgressIndicator(
                  color: Colors.white,
                  backgroundColor: Color(0x557DB7FF),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    OnboardingScreen.routeName,
                  ),
                  child: const Text('Start'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});
  static const routeName = '/onboarding';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 60),
              const AppCard(
                color: Color(0xFFE6F4FF),
                child: SizedBox(
                  height: 270,
                  child: Center(
                    child: Icon(
                      Icons.train_rounded,
                      size: 150,
                      color: AppColors.primary2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'Plan. Track. Travel.',
                style: TextStyle(
                  fontSize: 30,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Real-time public transport made easy for everyone across Malaysia.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 15),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (i) => Container(
                    width: i == 0 ? 22 : 8,
                    height: 8,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: i == 0 ? AppColors.primary : AppColors.line,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      LoginScreen.routeName,
                    ),
                    child: const Text('Skip'),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 120,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushReplacementNamed(
                        context,
                        LoginScreen.routeName,
                      ),
                      child: const Text('Next'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  static const routeName = '/login';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Welcome Back!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Login to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF434654), fontSize: 14),
                  ),
                  const SizedBox(height: 40),
                  const _Label('Email'),
                  const TextField(
                    decoration: InputDecoration(
                      hintText: 'youremail@gmail.com',
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _Label('Password'),
                  const TextField(
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      suffixIcon: Icon(Icons.visibility_off_outlined),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      AppShell.routeName,
                    ),
                    child: const Text('Login'),
                  ),
                  const SizedBox(height: 36),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('or continue with'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.g_mobiledata_rounded),
                    label: const Text('Google'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.facebook_rounded),
                    label: const Text('Facebook'),
                  ),
                  const SizedBox(height: 48),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, RegisterScreen.routeName),
                    child: const Text("Don't have an account? Register"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});
  static const routeName = '/register';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton()),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Create Account',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const Text(
            'Sign up to get started',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 28),
          const _Label('Full Name'),
          const TextField(decoration: InputDecoration(hintText: 'Yong Wen')),
          const SizedBox(height: 20),
          const _Label('Email'),
          const TextField(
            decoration: InputDecoration(hintText: 'youremail@gmail.com'),
          ),
          const SizedBox(height: 20),
          const _Label('Phone Number'),
          const TextField(
            decoration: InputDecoration(hintText: '012-345 6789'),
          ),
          const SizedBox(height: 20),
          const _Label('Password'),
          const TextField(
            obscureText: true,
            decoration: InputDecoration(hintText: '••••••••'),
          ),
          const SizedBox(height: 20),
          const _Label('Confirm Password'),
          const TextField(
            obscureText: true,
            decoration: InputDecoration(hintText: '••••••••'),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, AppShell.routeName),
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}
