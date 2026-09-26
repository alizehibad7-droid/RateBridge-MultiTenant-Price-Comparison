import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants/route_names.dart';
import '../../repositories/user_repository.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/admin_theme.dart';
import '../../utils/app_navigation.dart';
import '../../utils/chat_image_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/profile_layout.dart';
import 'admin_change_password_sheet.dart';

class AdminProfileView extends StatefulWidget {
  const AdminProfileView({super.key});

  @override
  State<AdminProfileView> createState() => _AdminProfileViewState();
}

class _AdminProfileViewState extends State<AdminProfileView> {
  bool _isUploadingImage = false;

  String _initials(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return trimmed.substring(0, 1).toUpperCase();
  }

  Future<void> _pickProfileImage() async {
    final source = await ChatImageUtils.showSourceSheet(context);
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    setState(() => _isUploadingImage = true);

    try {
      final bytes = await picked.readAsBytes();
      final url = await CloudinaryService.uploadImageBytes(
        bytes: bytes,
        folder: 'ratebridge/profiles',
        filename: picked.name.isNotEmpty ? picked.name : 'profile.jpg',
      );

      if (!mounted) return;

      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload profile image')),
        );
        return;
      }

      final uid = context.read<AuthViewModel>().user?.uid;
      if (uid == null) return;

      await context.read<UserRepository>().updateUserDoc(uid, {
        'profileImageUrl': url,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _openChangePassword(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email found on this account')),
      );
      return;
    }
    await showAdminChangePasswordSheet(context, email: email);
  }

  void _showAboutDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('RateBridge'),
        content: const Text(
          'Version 1.0.0\n\n'
          'A construction material price comparison platform for '
          "Pakistan's building industry.\n\n"
          'Powered by Usman Associates, Rawalpindi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await context.read<AuthViewModel>().signOut();
              if (mounted) {
                context.go(RouteNames.login);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AdminColors.red),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user;
    final topPadding = MediaQuery.paddingOf(context).top;
    final status = (user?.status ?? 'active');

    return Theme(
      data: AdminTheme.theme,
      child: Scaffold(
        backgroundColor: AdminColors.screenBg,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          leading: AppNavigation.leading(context, color: Colors.white),
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: Text(
            'My Profile',
            style: AdminTheme.titleStyle(size: 18).copyWith(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            ProfileHeroHeader(
              topPadding: topPadding,
              initials: _initials(user?.name),
              name: user?.name ?? 'Platform Administrator',
              subtitle: status.toUpperCase(),
              imageUrl: user?.profileImageUrl,
              isUploadingImage: _isUploadingImage,
              onPickImage: _pickProfileImage,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                children: [
                  ProfileSectionCard(
                    title: 'Account Information',
                    children: [
                      ProfileDetailRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: user?.email ?? 'N/A',
                      ),
                      ProfileDetailRow(
                        icon: Icons.badge_outlined,
                        label: 'Role',
                        value: user?.role ?? 'Administrator',
                      ),
                      ProfileDetailRow(
                        icon: Icons.info_outline_rounded,
                        label: 'Status',
                        value: status.toUpperCase(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _AccountSettingsCard(
                    onNotifications: () =>
                        context.push(RouteNames.adminNotifications),
                    onChangePassword: () =>
                        _openChangePassword(user?.email ?? ''),
                    onCategories: () =>
                        context.push(RouteNames.adminCategories),
                    onAbout: _showAboutDialog,
                  ),
                  const SizedBox(height: 12),
                  ProfileSignOutCard(onSignOut: _confirmSignOut),
                  const SizedBox(height: 20),
                  const ProfileVersionFooter(caption: 'Admin Portal'),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSettingsCard extends StatelessWidget {
  final VoidCallback onNotifications;
  final VoidCallback onChangePassword;
  final VoidCallback onCategories;
  final VoidCallback onAbout;

  const _AccountSettingsCard({
    required this.onNotifications,
    required this.onChangePassword,
    required this.onCategories,
    required this.onAbout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: profileSectionDecoration(),
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Account Settings',
            style: AdminTheme.titleStyle(size: 15),
          ),
          const SizedBox(height: 4),
          _SettingsRow(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            onTap: onNotifications,
          ),
          _SettingsRow(
            icon: Icons.lock_outline,
            title: 'Change Password',
            onTap: onChangePassword,
          ),
          _SettingsRow(
            icon: Icons.grid_view_rounded,
            title: 'Categories',
            onTap: onCategories,
          ),
          _SettingsRow(
            icon: Icons.info_outline,
            title: 'About RateBridge',
            onTap: onAbout,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool showDivider;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AdminColors.navy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: AdminColors.navy),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: AdminTheme.bodyStyle().copyWith(fontSize: 14),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AdminColors.textGrey,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: AdminColors.border.withValues(alpha: 0.8),
          ),
      ],
    );
  }
}
