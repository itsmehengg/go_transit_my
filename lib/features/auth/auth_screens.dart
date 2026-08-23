import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import 'auth_service.dart';
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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Enter your email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signIn(email: email, password: password);

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppShell.routeName);
    } catch (error) {
      setState(() => _errorMessage = _authService.readableAuthError(error));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'youremail@gmail.com',
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _Label('Password'),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _isLoading ? null : _login(),
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      suffixIcon: IconButton(
                        tooltip: _showPassword
                            ? 'Hide password'
                            : 'Show password',
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
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
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Login'),
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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  static const routeName = '/register';

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Enter your name, email, and password.');
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authService.signUp(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
      );

      if (!mounted) return;

      if (response.session == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created. Please confirm your email first.'),
          ),
        );
        Navigator.pushReplacementNamed(context, LoginScreen.routeName);
      } else {
        Navigator.pushReplacementNamed(context, AppShell.routeName);
      }
    } catch (error) {
      setState(() => _errorMessage = _authService.readableAuthError(error));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

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
          TextField(
            controller: _fullNameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(),
          ),
          const SizedBox(height: 20),
          const _Label('Email'),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(),
          ),
          const SizedBox(height: 20),
          const _Label('Phone Number'),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: '012-345 6789'),
          ),
          const SizedBox(height: 20),
          const _Label('Password'),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: '••••••••',
              suffixIcon: IconButton(
                tooltip: _showPassword ? 'Hide password' : 'Show password',
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _Label('Confirm Password'),
          TextField(
            controller: _confirmPasswordController,
            obscureText: !_showConfirmPassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _isLoading ? null : _register(),
            decoration: InputDecoration(
              hintText: '••••••••',
              suffixIcon: IconButton(
                tooltip: _showConfirmPassword
                    ? 'Hide confirm password'
                    : 'Show confirm password',
                onPressed: () => setState(
                  () => _showConfirmPassword = !_showConfirmPassword,
                ),
                icon: Icon(
                  _showConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton(
            onPressed: _isLoading ? null : _register,
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Register'),
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
