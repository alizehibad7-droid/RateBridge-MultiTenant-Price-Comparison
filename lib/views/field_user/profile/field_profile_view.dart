import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../constants/route_names.dart';
import '../../../models/rating_model.dart';
import '../../../repositories/user_repository.dart';
import '../../../services/cloudinary_service.dart';
import '../../../theme/field_theme.dart';
import '../../../utils/app_navigation.dart';
import '../../../utils/chat_image_utils.dart';
import '../../../utils/firestore_seed.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/field_user/field_catalog_viewmodel.dart';
import '../../../viewmodels/notification_viewmodel.dart';
import '../../../viewmodels/field_user/field_orders_viewmodel.dart';
import '../../../viewmodels/field_user/field_session_viewmodel.dart';
import '../shell/field_shell_view.dart';
import '../widgets/field_async_states.dart';
import 'field_change_password_sheet.dart';

class FieldProfileView extends StatefulWidget {
  const FieldProfileView({super.key});

  @override
  State<FieldProfileView> createState() => _FieldProfileViewState();
}

class _FieldProfileViewState extends State<FieldProfileView> {
  static const _headerGradient = LinearGradient(
    colors: [FieldColors.primaryNavy, FieldColors.primaryNavyDark],
  );

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  String? _saveError;
  String? _saveSuccess;
  bool _isSeeding = false;
  String? _seedMessage;
  bool _isEditing = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<FieldSessionViewModel>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FieldSessionViewModel>().refreshProfile();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _syncFromSession(FieldSessionViewModel session) {
    final user = session.user;
    if (user == null) return;
    if (_nameController.text != user.name) {
      _nameController.text = user.name;
    }
    if (_phoneController.text != user.phone) {
      _phoneController.text = user.phone;
    }
    if (_emailController.text != user.email) {
      _emailController.text = user.email;
    }
  }

  void _toggleEdit(FieldSessionViewModel session) {
    if (_isEditing) {
      _cancelEdit(session);
    } else {
      setState(() => _isEditing = true);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saveError = null;
      _saveSuccess = null;
    });

    final success = await context.read<FieldSessionViewModel>().updateProfile(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
        );

    if (!mounted) return;

    if (success) {
      setState(() {
        _saveSuccess = 'Profile updated';
        _isEditing = false;
      });
    } else {
      setState(() {
        _saveError = context.read<FieldSessionViewModel>().errorMessage ??
            'Could not save profile';
      });
    }
  }

  void _cancelEdit(FieldSessionViewModel session) {
    _syncFromSession(session);
    setState(() {
      _isEditing = false;
      _saveError = null;
      _saveSuccess = null;
    });
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

      final session = context.read<FieldSessionViewModel>();
      final uid = session.user?.uid;
      if (uid == null) return;

      await context.read<UserRepository>().updateUserDoc(uid, {
        'profileImageUrl': url,
      });
      await session.refreshProfile();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
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
    await showFieldChangePasswordSheet(context, email: email);
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

  Future<void> _seedTestData() async {
    final session = context.read<FieldSessionViewModel>();
    final companyId = session.companyId;
    final uid = session.user?.uid;
    if (companyId == null || uid == null) return;

    setState(() {
      _isSeeding = true;
      _seedMessage = null;
    });

    try {
      final result = await FirestoreSeed.seed(
        FirebaseFirestore.instance,
        companyId,
        'seed_supplier_ali',
        fieldUserUid: uid,
      );
      if (!mounted) return;
      setState(() => _seedMessage = result);
      if (!mounted) return;
      await context.read<FieldCatalogViewModel>().loadHomeData(companyId);
      if (!mounted) return;
      context.read<NotificationViewModel>().loadNotifications(uid);
    } catch (e) {
      if (mounted) setState(() => _seedMessage = 'Seed failed: $e');
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
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
            style: FilledButton.styleFrom(
              backgroundColor: FieldColors.statusDanger,
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  void _openOrdersSubTab(int index) {
    context.read<FieldOrdersViewModel>().requestOrdersSubTab(index);
    FieldShellScope.maybeOf(context)?.switchTab(FieldShellScope.ordersTabIndex);
  }

  void _openMessagesTab() {
    FieldShellScope.maybeOf(context)?.switchTab(FieldShellScope.messagesTabIndex);
  }

  void _openMyRatings() {
    final uid = context.read<FieldSessionViewModel>().user?.uid;
    if (uid == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FieldMyRatingsScreen(userId: uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<FieldSessionViewModel>();
    final orders = context.watch<FieldOrdersViewModel>();
    _syncFromSession(session);
    final user = session.user;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Theme(
      data: FieldTheme.theme,
      child: Scaffold(
        backgroundColor: FieldColors.screenBackground,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: AppNavigation.leading(context, color: Colors.white),
          title: Text(
            'My Profile',
            style: FieldTypography.titleMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            if (user != null)
              IconButton(
                onPressed: () => _toggleEdit(session),
                icon: Icon(
                  _isEditing ? Icons.close_rounded : Icons.edit_outlined,
                  color: Colors.white,
                ),
                tooltip: _isEditing ? 'Cancel edit' : 'Edit profile',
              ),
          ],
        ),
        body: user == null
            ? const FieldLoadingState(message: 'Loading profile…')
            : Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _ProfileHeaderSection(
                      topPadding: topPadding,
                      gradient: _headerGradient,
                      initials: _initials(user.name),
                      name: user.name,
                      companyName: session.companyName,
                      imageUrl: user.profileImageUrl,
                      isUploadingImage: _isUploadingImage,
                      onPickImage: _pickProfileImage,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: Column(
                        children: [
                          _ActivityStatsCard(
                            pending: orders.pendingCount,
                            active: orders.activeCount,
                            delivered: orders.deliveredCount,
                            onPendingTap: () => _openOrdersSubTab(0),
                            onActiveTap: () => _openOrdersSubTab(1),
                            onDeliveredTap: () => _openOrdersSubTab(2),
                          ),
                          const SizedBox(height: 12),
                          _PersonalDetailsCard(
                            isEditing: _isEditing,
                            nameController: _nameController,
                            phoneController: _phoneController,
                            emailController: _emailController,
                            companyName: session.companyName,
                            saveError: _saveError,
                            saveSuccess: _saveSuccess,
                            isSaving: session.isLoading,
                            onToggleEdit: () => _toggleEdit(session),
                            onCancel: () => _cancelEdit(session),
                            onSave: _save,
                          ),
                          const SizedBox(height: 12),
                          _MyAccountCard(
                            onOrders: () => _openOrdersSubTab(0),
                            onMessages: _openMessagesTab,
                            onRatings: _openMyRatings,
                            onChangePassword: () => _openChangePassword(user.email),
                            onAbout: _showAboutDialog,
                          ),
                          const SizedBox(height: 12),
                          _SignOutDangerCard(onSignOut: _confirmSignOut),
                          const SizedBox(height: 20),
                          const _VersionFooter(),
                          if (kDebugMode) ...[
                            const SizedBox(height: 24),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Text(
                              'Developer',
                              textAlign: TextAlign.center,
                              style: FieldTypography.labelSmall.copyWith(
                                color: FieldColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _isSeeding ? null : _seedTestData,
                              style: TextButton.styleFrom(
                                foregroundColor: FieldColors.textSecondary,
                              ),
                              child: _isSeeding
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Seed Test Data'),
                            ),
                            if (_seedMessage != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _seedMessage!,
                                textAlign: TextAlign.center,
                                style: FieldTypography.labelSmall.copyWith(
                                  color: FieldColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                          const SizedBox(height: 100),
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

// ─── Part 1: Profile header ──────────────────────────────────────────────────

class _ProfileHeaderSection extends StatelessWidget {
  final double topPadding;
  final LinearGradient gradient;
  final String initials;
  final String name;
  final String companyName;
  final String? imageUrl;
  final bool isUploadingImage;
  final VoidCallback onPickImage;

  const _ProfileHeaderSection({
    required this.topPadding,
    required this.gradient,
    required this.initials,
    required this.name,
    required this.companyName,
    this.imageUrl,
    required this.isUploadingImage,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    final gradientHeight = 140.0;
    final avatarOverlap = 48.0;

    return Column(
      children: [
        SizedBox(
          height: topPadding + gradientHeight + avatarOverlap,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topPadding + gradientHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: gradient),
                ),
              ),
              Positioned(
                top: topPadding + gradientHeight - avatarOverlap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: FieldColors.surfaceWhite,
                        border: Border.all(
                          color: FieldColors.surfaceWhite,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: imageUrl != null && imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => _initialsAvatar(),
                                errorWidget: (_, __, ___) => _initialsAvatar(),
                              )
                            : _initialsAvatar(),
                      ),
                    ),
                    if (isUploadingImage)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!isUploadingImage)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: onPickImage,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: FieldColors.accentAmber,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 14,
                              color: FieldColors.primaryNavy,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          textAlign: TextAlign.center,
          style: FieldTypography.titleMedium.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: FieldColors.primaryNavy,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: FieldColors.accentAmber.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            companyName,
            style: FieldTypography.labelSmall.copyWith(
              color: FieldColors.primaryNavy,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _initialsAvatar() {
    return Container(
      color: FieldColors.accentAmber,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: FieldTypography.titleMedium.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: FieldColors.primaryNavy,
        ),
      ),
    );
  }
}

// ─── Part 2: Activity stats ──────────────────────────────────────────────────

class _ActivityStatsCard extends StatelessWidget {
  final int pending;
  final int active;
  final int delivered;
  final VoidCallback onPendingTap;
  final VoidCallback onActiveTap;
  final VoidCallback onDeliveredTap;

  const _ActivityStatsCard({
    required this.pending,
    required this.active,
    required this.delivered,
    required this.onPendingTap,
    required this.onActiveTap,
    required this.onDeliveredTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: _StatSection(
              count: pending,
              label: 'Pending',
              onTap: onPendingTap,
            ),
          ),
          Container(width: 1, height: 36, color: FieldColors.borderSubtle),
          Expanded(
            child: _StatSection(
              count: active,
              label: 'Active',
              onTap: onActiveTap,
            ),
          ),
          Container(width: 1, height: 36, color: FieldColors.borderSubtle),
          Expanded(
            child: _StatSection(
              count: delivered,
              label: 'Delivered',
              onTap: onDeliveredTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatSection extends StatelessWidget {
  final int count;
  final String label;
  final VoidCallback onTap;

  const _StatSection({
    required this.count,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            '$count',
            style: FieldTypography.headlineMedium.copyWith(
              color: FieldColors.accentAmber,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: FieldTypography.labelSmall.copyWith(
              color: FieldColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Part 3: Personal details ────────────────────────────────────────────────

class _PersonalDetailsCard extends StatelessWidget {
  final bool isEditing;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final String companyName;
  final String? saveError;
  final String? saveSuccess;
  final bool isSaving;
  final VoidCallback onToggleEdit;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const _PersonalDetailsCard({
    required this.isEditing,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.companyName,
    this.saveError,
    this.saveSuccess,
    required this.isSaving,
    required this.onToggleEdit,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Personal Details',
                style: FieldTypography.titleMedium.copyWith(
                  color: FieldColors.primaryNavy,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onToggleEdit,
                icon: Icon(
                  isEditing ? Icons.close_rounded : Icons.edit_outlined,
                  size: 20,
                  color: FieldColors.textMuted,
                ),
                tooltip: isEditing ? 'Cancel edit' : 'Edit',
              ),
            ],
          ),
          if (!isEditing) ...[
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Full Name',
              value: nameController.text,
            ),
            _DetailRow(
              icon: Icons.phone_outlined,
              label: 'Phone Number',
              value: phoneController.text,
            ),
            _DetailRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: emailController.text,
            ),
            _DetailRow(
              icon: Icons.business_outlined,
              label: 'Company',
              value: companyName,
            ),
          ] else ...[
            _EditableField(
              label: 'Full Name',
              controller: nameController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _EditableField(
              label: 'Phone Number',
              controller: phoneController,
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Phone number is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _ReadOnlyField(
              label: 'Email',
              value: emailController.text,
            ),
            const SizedBox(height: 12),
            _ReadOnlyField(
              label: 'Company',
              value: companyName,
            ),
            if (saveSuccess != null) ...[
              const SizedBox(height: 12),
              Text(
                saveSuccess!,
                style: FieldTypography.bodyMedium.copyWith(
                  color: FieldColors.statusSuccess,
                ),
              ),
            ],
            if (saveError != null) ...[
              const SizedBox(height: 12),
              Text(
                saveError!,
                style: FieldTypography.bodyMedium.copyWith(
                  color: FieldColors.statusDanger,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: isSaving ? null : onSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: FieldColors.accentAmber,
                      foregroundColor: FieldColors.primaryNavy,
                    ),
                    child: isSaving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: FieldColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: FieldTypography.labelSmall.copyWith(fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: FieldTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: FieldColors.primaryNavy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _EditableField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: FieldTypography.labelSmall),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
        ),
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;

  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: FieldTypography.labelSmall),
        const SizedBox(height: 6),
        InputDecorator(
          decoration: const InputDecoration(
            suffixIcon: Icon(Icons.lock_outline, size: 18),
          ),
          child: Text(
            value,
            style: FieldTypography.bodyMedium.copyWith(
              color: FieldColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Part 4: My account ──────────────────────────────────────────────────────

class _MyAccountCard extends StatelessWidget {
  final VoidCallback onOrders;
  final VoidCallback onMessages;
  final VoidCallback onRatings;
  final VoidCallback onChangePassword;
  final VoidCallback onAbout;

  const _MyAccountCard({
    required this.onOrders,
    required this.onMessages,
    required this.onRatings,
    required this.onChangePassword,
    required this.onAbout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'My Account',
            style: FieldTypography.titleMedium.copyWith(
              color: FieldColors.primaryNavy,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          _AccountSettingsRow(
            emoji: '📦',
            title: 'My Orders',
            onTap: onOrders,
          ),
          _AccountSettingsRow(
            emoji: '💬',
            title: 'Messages',
            onTap: onMessages,
          ),
          _AccountSettingsRow(
            emoji: '⭐',
            title: 'My Ratings',
            onTap: onRatings,
          ),
          _AccountSettingsRow(
            emoji: '🔒',
            title: 'Change Password',
            onTap: onChangePassword,
          ),
          _AccountSettingsRow(
            emoji: 'ℹ️',
            title: 'About RateBridge',
            onTap: onAbout,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _AccountSettingsRow extends StatelessWidget {
  final String emoji;
  final String title;
  final VoidCallback onTap;
  final bool showDivider;

  const _AccountSettingsRow({
    required this.emoji,
    required this.title,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: FieldTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      color: FieldColors.primaryNavy,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: FieldColors.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: FieldColors.borderSubtle.withValues(alpha: 0.8),
          ),
      ],
    );
  }
}

// ─── Part 5: Sign out ────────────────────────────────────────────────────────

class _SignOutDangerCard extends StatelessWidget {
  final VoidCallback onSignOut;

  const _SignOutDangerCard({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FieldColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: onSignOut,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: FieldColors.statusDanger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.logout,
                      size: 18,
                      color: FieldColors.statusDanger,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Sign Out',
                    style: FieldTypography.bodyMedium.copyWith(
                      fontSize: 14,
                      color: FieldColors.statusDanger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: 3,
              child: ColoredBox(color: FieldColors.statusDanger),
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'RateBridge v1.0.0',
          style: FieldTypography.labelSmall.copyWith(
            color: FieldColors.textMuted,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Field User Portal',
          style: FieldTypography.labelSmall.copyWith(
            color: FieldColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: FieldColors.borderSubtle),
    boxShadow: [
      BoxShadow(
        color: FieldColors.primaryNavy.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

// ─── My ratings screen ───────────────────────────────────────────────────────

class _FieldMyRatingsScreen extends StatelessWidget {
  final String userId;

  const _FieldMyRatingsScreen({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FieldTheme.theme,
      child: Scaffold(
        backgroundColor: FieldColors.screenBackground,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: AppNavigation.leading(context, color: Colors.white),
          backgroundColor: FieldColors.primaryNavy,
          foregroundColor: Colors.white,
          title: const Text('My Ratings'),
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('ratings')
              .where('userId', isEqualTo: userId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Could not load ratings',
                  style: FieldTypography.bodyMedium,
                ),
              );
            }

            final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
              snapshot.data?.docs ?? [],
            )..sort((a, b) {
                final aDate = a.data()['createdAt'];
                final bDate = b.data()['createdAt'];
                if (aDate is Timestamp && bDate is Timestamp) {
                  return bDate.compareTo(aDate);
                }
                return 0;
              });
            if (docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_outline_rounded,
                        size: 56,
                        color: FieldColors.textMuted.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No ratings yet',
                        style: FieldTypography.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Rate suppliers after confirming delivery on your orders.',
                        textAlign: TextAlign.center,
                        style: FieldTypography.bodyMedium.copyWith(
                          color: FieldColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final rating =
                    RatingModel.fromMap(docs[index].id, docs[index].data());
                return Container(
                  decoration: _cardDecoration(),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rating.materialName,
                        style: FieldTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: FieldColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ...List.generate(5, (i) {
                            return Icon(
                              i < rating.rating.floor()
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 16,
                              color: FieldColors.accentAmber,
                            );
                          }),
                          const SizedBox(width: 6),
                          Text(
                            rating.rating.toStringAsFixed(1),
                            style: FieldTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (rating.comment.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          rating.comment,
                          style: FieldTypography.bodyMedium.copyWith(
                            color: FieldColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
