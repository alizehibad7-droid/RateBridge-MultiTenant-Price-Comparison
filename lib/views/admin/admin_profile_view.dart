import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../constants/route_names.dart';
import '../../repositories/user_repository.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/admin_theme.dart';
import '../../utils/app_navigation.dart';
import '../../utils/chat_image_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/profile_layout.dart';
import '../../widgets/admin/admin_widgets.dart';

class AdminProfileView extends StatefulWidget {
  const AdminProfileView({super.key});

  @override
  State<AdminProfileView> createState() => _AdminProfileViewState();
}

class _AdminProfileViewState extends State<AdminProfileView> {
  bool _isUploadingImage = false;

  bool _checkIsDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1024;
  }

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
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await context.read<AuthViewModel>().signOut();
              if (mounted) {
                context.go(RouteNames.login);
              }
            },
            child: const Text('Sign out', style: TextStyle(color: AdminColors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkIsDesktop(context)) return _buildDesktopLayout(context);
    
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
                      ProfileDetailRow(
                        icon: Icons.login_rounded,
                        label: 'Last Login',
                        value: DateFormat('MMM d, h:mm a').format(DateTime.now()),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _AccountSettingsCard(
                    onNotifications: () =>
                        context.push(RouteNames.adminNotifications),
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

  Widget _buildDesktopLayout(BuildContext context) {
    final user = context.watch<AuthViewModel>().user;
    final status = (user?.status ?? 'active');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings & Profile', style: AdminTheme.titleStyle(size: 28)),
          const SizedBox(height: 8),
          Text('Manage your account preferences and platform configuration.', style: AdminTheme.mutedStyle(size: 16)),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: Profile Summary
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AdminTheme.cardDecoration(),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AdminColors.amber.withValues(alpha: 0.1),
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                            ),
                            child: ClipOval(
                              child: user?.profileImageUrl != null
                                  ? Image.network(user!.profileImageUrl!, fit: BoxFit.cover)
                                  : Center(
                                      child: Text(
                                        _initials(user?.name),
                                        style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, color: AdminColors.navy),
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickProfileImage,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(color: AdminColors.amber, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(user?.name ?? 'Admin', style: AdminTheme.titleStyle(size: 20)),
                      Text(user?.role ?? 'Administrator', style: AdminTheme.mutedStyle()),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AdminColors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: AdminColors.green),
                        ),
                      ),
                      const Divider(height: 48),
                      _ProfileInfoItem(label: 'Email Address', value: user?.email ?? 'N/A', icon: Icons.email_outlined),
                      const SizedBox(height: 16),
                      _ProfileInfoItem(label: 'Last Login', value: DateFormat('MMM d, h:mm a').format(DateTime.now()), icon: Icons.login_rounded),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 32),
              // Right column: Actions and Settings
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _DesktopSettingsSection(
                      title: 'Account Settings',
                      children: [
                        _DesktopSettingsTile(
                          icon: Icons.notifications_none_rounded,
                          title: 'Notifications',
                          subtitle: 'Click and see notifications',
                          onTap: () => context.push(RouteNames.adminNotifications),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _DesktopSettingsSection(
                      title: 'Platform Management',
                      children: [
                        _DesktopSettingsTile(
                          icon: Icons.grid_view_rounded,
                          title: 'Material Taxonomy',
                          subtitle: 'Manage construction material categories, units, and brands.',
                          onTap: () => context.push(RouteNames.adminCategories),
                        ),
                        _DesktopSettingsTile(
                          icon: Icons.info_outline_rounded,
                          title: 'About RateBridge',
                          subtitle: 'View system version, legal information, and platform credits.',
                          onTap: _showAboutDialog,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _DesktopSettingsSection(
                      title: 'Session',
                      children: [
                        _DesktopSettingsTile(
                          icon: Icons.logout_rounded,
                          title: 'Sign Out',
                          subtitle: 'Securely end your current administrative session.',
                          onTap: _confirmSignOut,
                          destructive: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProfileInfoItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AdminColors.textGrey),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AdminTheme.mutedStyle(size: 11).copyWith(fontWeight: FontWeight.bold)),
            Text(value, style: AdminTheme.bodyStyle()),
          ],
        ),
      ],
    );
  }
}

class _DesktopSettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DesktopSettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(title.toUpperCase(), style: AdminTheme.sectionHeaderStyle()),
        ),
        AdminCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _DesktopSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  const _DesktopSettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AdminColors.red : AdminColors.navy;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AdminTheme.titleStyle(size: 16).copyWith(color: color)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AdminTheme.mutedStyle()),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AdminColors.textGrey),
          ],
        ),
      ),
    );
  }
}

class _AccountSettingsCard extends StatelessWidget {
  final VoidCallback onNotifications;
  final VoidCallback onCategories;
  final VoidCallback onAbout;

  const _AccountSettingsCard({
    required this.onNotifications,
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