import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  ProfileService({SupabaseClient? client, ImagePicker? imagePicker})
      : _client = client ?? Supabase.instance.client,
        _imagePicker = imagePicker ?? ImagePicker();

  final SupabaseClient _client;
  final ImagePicker _imagePicker;

  User? get currentUser => _client.auth.currentUser;

  Map<String, dynamic>? _fallbackProfile(User? user) {
    if (user == null) return null;
    return {
      'id': user.id,
      'full_name': user.userMetadata?['full_name'] ?? '',
      'email': user.email ?? '',
      'phone': user.userMetadata?['phone'] ?? '',
      'membership_tier': user.userMetadata?['membership_tier'] ?? 'Free User',
      'avatar_path': user.userMetadata?['avatar_path'],
    };
  }

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final profile = await _client
          .from('app_users')
          .select('id, full_name, email, phone, membership_tier, avatar_path')
          .eq('id', user.id)
          .maybeSingle();
      return profile ?? _fallbackProfile(user);
    } catch (_) {
      return _fallbackProfile(user);
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    required String phone,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException('Please log in before updating your profile.');
    }

    final cleanName = fullName.trim();
    final cleanPhone = phone.trim();

    await _client.auth.updateUser(
      UserAttributes(
        data: {
          ...?user.userMetadata,
          'full_name': cleanName,
          'phone': cleanPhone,
        },
      ),
    );

    try {
      await _client.from('app_users').upsert({
        'id': user.id,
        'full_name': cleanName,
        'email': user.email,
        'phone': cleanPhone,
      });
    } catch (_) {}

    final refreshedUser = currentUser;
    final profile = await getCurrentProfile();
    return profile ??
        {
          'id': refreshedUser?.id ?? user.id,
          'full_name': cleanName,
          'email': refreshedUser?.email ?? user.email ?? '',
          'phone': cleanPhone,
          'membership_tier': 'Free User',
          'avatar_path': refreshedUser?.userMetadata?['avatar_path'],
        };
  }

  Future<String?> createAvatarSignedUrl(String? avatarPath) async {
    if (avatarPath == null || avatarPath.isEmpty) return null;
    try {
      return await _client.storage.from('avatars').createSignedUrl(avatarPath, 60 * 60);
    } catch (_) {
      return null;
    }
  }

  Future<XFile?> pickProfilePhoto() {
    return _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
  }

  Future<String> uploadProfilePhoto(XFile image) async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException('Please log in before uploading a profile photo.');
    }

    final bytes = await image.readAsBytes();
    final extension = _fileExtension(image.name);
    final filePath = '${user.id}/profile-${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _client.storage.from('avatars').uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentType(extension),
            upsert: true,
          ),
        );

    await _client.auth.updateUser(
      UserAttributes(
        data: {
          ...?user.userMetadata,
          'avatar_path': filePath,
        },
      ),
    );

    try {
      await _client.from('app_users').upsert({
        'id': user.id,
        'email': user.email,
        'full_name': user.userMetadata?['full_name'] ?? '',
        'phone': user.userMetadata?['phone'] ?? '',
        'avatar_path': filePath,
      });
    } catch (_) {}

    return filePath;
  }

  String _fileExtension(String fileName) {
    final parts = fileName.toLowerCase().split('.');
    if (parts.length < 2) return 'jpg';
    final extension = parts.last;
    if (extension == 'jpeg' || extension == 'jpg') return 'jpg';
    if (extension == 'png') return 'png';
    if (extension == 'webp') return 'webp';
    return 'jpg';
  }

  String _contentType(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}
