import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../auth/auth_service.dart';
import '../auth/auth_screens.dart';
import 'account_screens.dart';
import 'personalisation_screens.dart';
import 'personalisation_service.dart';
import 'profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _profileService = ProfileService();
  final _personalisation = PersonalisationService.instance;

  Map<String, dynamic>? _profile;
  String? _avatarSignedUrl;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final profile = await _profileService.getCurrentProfile();
      final avatarPath = profile?['avatar_path'] as String? ??
          _authService.currentUser?.userMetadata?['avatar_path'] as String?;
      final avatarSignedUrl = await _profileService.createAvatarSignedUrl(avatarPath);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _avatarSignedUrl = avatarSignedUrl;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.toString();
      });
    }
  }

  Future<void> _selectAndUploadPhoto() async {
    try {
      final image = await _profileService.pickProfilePhoto();
      if (image == null) return;
      setState(() => _isUploadingPhoto = true);
      final avatarPath = await _profileService.uploadProfilePhoto(image);
      final avatarSignedUrl = await _profileService.createAvatarSignedUrl(avatarPath);
      if (!mounted) return;
      setState(() {
        _profile = {...?_profile, 'avatar_path': avatarPath};
        _avatarSignedUrl = avatarSignedUrl;
        _isUploadingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isUploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update photo: $error')),
      );
    }
  }

  Future<void> _showEditProfileDialog() async {
    final user = _authService.currentUser;
    final profile = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EditProfileDialog(
        profileService: _profileService,
        initialFullName: _profile?['full_name'] as String? ??
            user?.userMetadata?['full_name'] as String? ??
            '',
        initialPhone: _profile?['phone'] as String? ??
            user?.userMetadata?['phone'] as String? ??
            '',
      ),
    );
    if (profile == null || !mounted) return;
    setState(() => _profile = profile);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated')),
    );
  }

  Future<void> _logout() async {
    try {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        LoginScreen.routeName,
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authService.readableAuthError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final fullName = _profile?['full_name'] as String? ??
        user?.userMetadata?['full_name'] as String? ??
        'GoTransit User';
    final phone = _profile?['phone'] as String? ??
        user?.userMetadata?['phone'] as String? ??
        '';

    return AnimatedBuilder(
      animation: _personalisation,
      builder: (context, _) => Scaffold(
        body: RefreshIndicator(
          onRefresh: _loadProfile,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: const Color(0xFFDDEBFF),
                          backgroundImage: _avatarSignedUrl == null || _avatarSignedUrl!.isEmpty
                              ? null
                              : NetworkImage(_avatarSignedUrl!),
                          child: _avatarSignedUrl == null || _avatarSignedUrl!.isEmpty
                              ? const Icon(Icons.person, size: 38, color: AppColors.primary)
                              : null,
                        ),
                        Positioned(
                          right: -8,
                          bottom: -8,
                          child: IconButton.filled(
                            tooltip: 'Change profile picture',
                            onPressed: _isUploadingPhoto ? null : _selectAndUploadPhoto,
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
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
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
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? 'No email',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFFDDEBFF)),
                          ),
                          if (phone.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              phone,
                              style: const TextStyle(color: Color(0xFFDDEBFF)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (_loadError != null) ...[
                      AppCard(
                        color: const Color(0xFFFFF1F2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Profile data could not be loaded',
                              style: TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(_loadError!, style: const TextStyle(color: AppColors.muted)),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _loadProfile,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _ProfileRow(
                      Icons.account_circle_rounded,
                      'Account Information',
                      subtitle: user?.email,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AccountInformationScreen()),
                      ),
                    ),
                    _ProfileRow(
                      Icons.edit_rounded,
                      'Edit Profile',
                      subtitle: phone.isEmpty ? 'Add name and phone' : phone,
                      onTap: _showEditProfileDialog,
                    ),
                    _ProfileRow(
                      Icons.lock_rounded,
                      'Change Password',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                      ),
                    ),
                    _ProfileRow(
                      Icons.favorite_rounded,
                      'Favourite Stations',
                      subtitle: '${_personalisation.favouriteStations.length}',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FavouriteStationsScreen()),
                      ),
                    ),
                    _ProfileRow(
                      Icons.route_rounded,
                      'Favourite Routes',
                      subtitle: '${_personalisation.favouriteRoutes.length}',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FavouriteRoutesScreen()),
                      ),
                    ),
                    _ProfileRow(
                      Icons.history_rounded,
                      'Recent Searches',
                      subtitle: '${_personalisation.recentSearches.length}',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RecentSearchesScreen()),
                      ),
                    ),
                    _ProfileRow(
                      Icons.directions_transit_rounded,
                      'Preferred Transport',
                      subtitle: _personalisation.preferredTransport,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PreferredTransportScreen()),
                      ),
                    ),
                    _ProfileRow(
                      Icons.notifications_rounded,
                      'Notification Settings',
                      subtitle: _personalisation.notificationsEnabled ? 'On' : 'Off',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
                      ),
                    ),
                    _ProfileRow(
                      Icons.language_rounded,
                      'Language',
                      subtitle: _personalisation.language,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LanguageScreen()),
                      ),
                    ),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        secondary: const Icon(Icons.dark_mode_rounded, color: AppColors.primary),
                        title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: const Text('Saved on this device'),
                        value: _personalisation.darkMode,
                        onChanged: _personalisation.setDarkMode,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ProfileRow(
                      Icons.help_outline_rounded,
                      'Help & Support',
                      onTap: () => showModalBottomSheet<void>(
                        context: context,
                        showDragHandle: true,
                        builder: (_) => const _HelpSheet(),
                      ),
                    ),
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
        ),
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

    if (fullName.length < 2) {
      setState(() => _errorMessage = 'Please enter your full name.');
      return;
    }
    if (phone.isNotEmpty && !RegExp(r'^[0-9+() -]{7,20}$').hasMatch(phone)) {
      setState(() => _errorMessage = 'Please enter a valid phone number.');
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
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_isSaving) _saveProfile();
              },
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700),
              ),
            ],
          ],
        ),
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
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
      ),
    );
  }
}

class _HelpSheet extends StatelessWidget {
  const _HelpSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Help & Support', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.info_outline_rounded, color: AppColors.primary),
              title: Text('GoTransit MY', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('Smart Public Transport Tracker for Malaysian public transport data.'),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.lock_outline_rounded, color: AppColors.primary),
              title: Text('Account help', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('Use Forgot Password on the login screen if you cannot access your account.'),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.refresh_rounded, color: AppColors.primary),
              title: Text('Data not updating?', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('Check your internet connection and use refresh on the related screen.'),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
