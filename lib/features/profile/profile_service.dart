import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  ProfileService({SupabaseClient? client, ImagePicker? imagePicker})
    : _client = client ?? Supabase.instance.client,
      _imagePicker = imagePicker ?? ImagePicker();

  final SupabaseClient _client;
  final ImagePicker _imagePicker;

  User? get currentUser => _client.auth.currentUser;

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    return _client
        .from('app_users')
        .select('id, full_name, email, phone, membership_tier, avatar_path')
        .eq('id', user.id)
        .maybeSingle();
  }

  Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    required String phone,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException('Please log in before updating your profile.');
    }

    final profile = await _client
        .from('app_users')
        .update({'full_name': fullName.trim(), 'phone': phone.trim()})
        .eq('id', user.id)
        .select('id, full_name, email, phone, membership_tier, avatar_path')
        .single();

    await _client.auth.updateUser(
      UserAttributes(
        data: {'full_name': fullName.trim(), 'phone': phone.trim()},
      ),
    );

    return profile;
  }

  Future<String?> createAvatarSignedUrl(String? avatarPath) {
    if (avatarPath == null || avatarPath.isEmpty) {
      return Future.value();
    }

    return _client.storage.from('avatars').createSignedUrl(avatarPath, 60 * 60);
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
      throw const AuthException(
        'Please log in before uploading a profile photo.',
      );
    }

    final bytes = await image.readAsBytes();
    final extension = _fileExtension(image.name);
    final filePath =
        '${user.id}/profile-${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _client.storage
        .from('avatars')
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentType(extension),
            upsert: true,
          ),
        );

    await _client
        .from('app_users')
        .update({'avatar_path': filePath})
        .eq('id', user.id);

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
