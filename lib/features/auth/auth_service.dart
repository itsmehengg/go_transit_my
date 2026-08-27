import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  bool get isSignedIn => currentUser != null;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: 'gotransitmy://login',
      data: {'full_name': fullName.trim(), 'phone': phone.trim()},
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'gotransitmy://reset-password',
    );
  }

  Future<UserResponse> updatePassword(String password) {
    return _client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }

  String readableAuthError(Object error) {
    if (error is AuthException) {
      return switch (error.code) {
        'email_not_confirmed' => 'Please confirm your email before logging in.',
        'invalid_credentials' => 'Email or password is incorrect.',
        'email_address_invalid' => 'Please enter a valid email address.',
        'over_email_send_rate_limit' =>
          'Too many email attempts. Wait a few minutes, then try again.',
        'user_already_exists' || 'email_exists' =>
          'This email is already registered. Try logging in instead.',
        'weak_password' => 'Please choose a stronger password.',
        _ => error.message,
      };
    }
    return error.toString();
  }
}
