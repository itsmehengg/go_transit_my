import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/demo_data.dart';
import '../auth/auth_service.dart';
import 'profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _profileService = ProfileService();
  Map<String, dynamic>? _profile;
  String? _avatarSignedUrl;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileService.getCurrentProfile();
    final avatarSignedUrl = await _profileService.createAvatarSignedUrl(
      profile?['avatar_path'] as String?,
    );
    if (!mounted) return;

    setState(() {
      _profile = profile;
      _avatarSignedUrl = avatarSignedUrl;
      _isLoading = false;
    });
  }

  Future<void> _selectAndUploadPhoto() async {
    try {
      final image = await _profileService.pickProfilePhoto();
      if (image == null) return;

      setState(() => _isUploadingPhoto = true);
      final avatarPath = await _profileService.uploadProfilePhoto(image);
      final avatarSignedUrl = await _profileService.createAvatarSignedUrl(
        avatarPath,
      );

      if (!mounted) return;
      setState(() {
        _profile = {...?_profile, 'avatar_path': avatarPath};
        _avatarSignedUrl = avatarSignedUrl;
        _isUploadingPhoto = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _showEditProfileDialog() async {
    final user = _authService.currentUser;
    final profile = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EditProfileDialog(
        profileService: _profileService,
        initialFullName:
            _profile?['full_name'] as String? ??
            user?.userMetadata?['full_name'] as String? ??
            '',
        initialPhone:
            _profile?['phone'] as String? ??
            user?.userMetadata?['phone'] as String? ??
            '',
      ),
    );

    if (profile == null || !mounted) return;

    setState(() => _profile = profile);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile updated')));
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final fullName =
        _profile?['full_name'] as String? ??
        user?.userMetadata?['full_name'] as String? ??
        'GoTransit User';
    final tier = _profile?['membership_tier'] as String? ?? 'Free User';

    return Scaffold(
      body: ListView(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 64, 20, 28),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: const Color(0xFFDDEBFF),
                      backgroundImage:
                          _avatarSignedUrl == null || _avatarSignedUrl!.isEmpty
                          ? null
                          : NetworkImage(_avatarSignedUrl!),
                      child:
                          _avatarSignedUrl == null || _avatarSignedUrl!.isEmpty
                          ? const Icon(
                              Icons.person,
                              size: 38,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                    Positioned(
                      right: -8,
                      bottom: -8,
                      child: IconButton.filled(
                        onPressed: _isUploadingPhoto
                            ? null
                            : _selectAndUploadPhoto,
                        icon: _isUploadingPhoto
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.camera_alt_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLoading ? 'Loading...' : fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      tier,
                      style: const TextStyle(color: Color(0xFFDDEBFF)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _ProfileRow(
                  Icons.edit_rounded,
                  'Edit Profile',
                  subtitle: _profile?['phone'] as String?,
                  onTap: _showEditProfileDialog,
                ),
                const _ProfileRow(Icons.insights_rounded, 'My Stats'),
                _ProfileRow(
                  Icons.favorite_rounded,
                  'Favourite Stations',
                  subtitle: stations.length.toString(),
                ),
                const _ProfileRow(Icons.route_rounded, 'Favourite Routes'),
                const _ProfileRow(Icons.history_rounded, 'Recent Searches'),
                const _ProfileRow(
                  Icons.notifications_rounded,
                  'Notification Settings',
                ),
                const _ProfileRow(
                  Icons.language_rounded,
                  'Language',
                  subtitle: 'English / Bahasa Melayu',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(
                    Icons.dark_mode_rounded,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Dark Mode',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Stored locally with SharedPreferences later',
                  ),
                  value: false,
                  onChanged: (_) {},
                ),
                const Divider(),
                const _ProfileRow(Icons.help_outline_rounded, 'Help & Support'),
                _ProfileRow(
                  Icons.logout_rounded,
                  'Logout',
                  danger: true,
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.profileService,
    required this.initialFullName,
    required this.initialPhone,
  });

  final ProfileService profileService;
  final String initialFullName;
  final String initialPhone;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialFullName);
    _phoneController = TextEditingController(text: widget.initialPhone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final fullName = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (fullName.isEmpty) {
      setState(() => _errorMessage = 'Full name is required.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final profile = await widget.profileService.updateProfile(
        fullName: fullName,
        phone: phone,
      );

      if (!mounted) return;
      Navigator.pop(context, profile);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Full Name'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _isSaving ? null : _saveProfile(),
            decoration: const InputDecoration(labelText: 'Phone Number'),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveProfile,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow(
    this.icon,
    this.label, {
    this.subtitle,
    this.danger = false,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.primary;
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: danger ? color : null,
          ),
        ),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
