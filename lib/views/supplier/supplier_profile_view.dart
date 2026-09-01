// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/route_names.dart';
import '../../models/user_model.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/supplier_theme.dart';
import '../../utils/app_navigation.dart';
import '../../utils/app_theme.dart';
import '../../utils/chat_image_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/supplier_nav_bar.dart';
import 'supplier_change_password_sheet.dart';
import 'supplier_notification_prefs_sheet.dart';

const _businessTypes = [
  'Material Supplier',
  'Wholesaler',
  'Manufacturer',
  'Retailer',
];

class SupplierProfileView extends StatefulWidget {
  const SupplierProfileView({super.key});

  @override
  State<SupplierProfileView> createState() => _SupplierProfileViewState();
}

class _SupplierProfileViewState extends State<SupplierProfileView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  late TextEditingController _addressController;
  late TextEditingController _cnicController;

  bool _isUploadingImage = false;
  bool _profileLoaded = false;
  bool _isEditing = false;
  String _businessType = 'Material Supplier';
  UserModel? _editSnapshot;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _cityController = TextEditingController();
    _addressController = TextEditingController();
    _cnicController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthViewModel>();
    final vm = context.read<SupplierViewModel>();
    final profile = vm.profile ?? auth.user;
    if (profile != null) {
      _fillControllers(profile);
    } else {
      await vm.loadProfile();
      if (!mounted) return;
      final loaded = vm.profile;
      if (loaded != null) _fillControllers(loaded);
    }
    if (!mounted) return;
    setState(() => _profileLoaded = true);
  }

  void _fillControllers(UserModel profile) {
    _nameController.text = profile.name;
    _phoneController.text = profile.phone;
    _cityController.text = profile.city;
    _addressController.text = profile.address ?? '';
    _cnicController.text = profile.cnic ?? '';
    final bt = profile.businessType?.trim();
    _businessType = (bt != null && bt.isNotEmpty) ? bt : 'Material Supplier';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _cnicController.dispose();
    super.dispose();
  }

  String _initials(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }

  String _maskedCnic(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '—';
    return 'XXXXX-XXXXXXX-X';
  }

  int _completedOrdersCount(SupplierViewModel vm) {
    return vm.orders
        .where((o) => o.status.toLowerCase() == 'confirmed')
        .length;
  }

  void _toggleEditMode(UserModel? profile) {
    if (_isEditing) {
      _cancelEdit(profile);
    } else if (profile != null) {
      _editSnapshot = profile;
      setState(() => _isEditing = true);
    }
  }

  void _cancelEdit(UserModel? profile) {
    if (_editSnapshot != null) {
      _fillControllers(_editSnapshot!);
    } else if (profile != null) {
      _fillControllers(profile);
    }
    setState(() => _isEditing = false);
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

      await context.read<SupplierViewModel>().updateProfile({
        'profileImageUrl': url,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _saveProfile(SupplierViewModel viewModel, UserModel? profile) async {
    if (!_formKey.currentState!.validate()) return;

    await viewModel.updateProfile({
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'city': _cityController.text.trim(),
      'address': _addressController.text.trim(),
      'businessType': _businessType.trim(),
    });

    if (!mounted) return;
    if (profile != null) {
      _editSnapshot = profile.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        city: _cityController.text.trim(),
        address: _addressController.text.trim(),
        businessType: _businessType.trim(),
      );
    }
    setState(() => _isEditing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully')),
    );
  }

  Future<void> _openNotificationPrefs() async {
    final vm = context.read<SupplierViewModel>();
    if (!vm.notificationPrefsLoaded) {
      await vm.loadNotificationPreferences();
    }
    if (!mounted) return;
    await showSupplierNotificationPrefsSheet(context);
  }

  Future<void> _openChangePassword(String email) async {
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email found on this account')),
      );
      return;
    }
    await showSupplierChangePasswordSheet(context, email: email);
  }

  Future<void> _confirmSignOut(AuthViewModel authVM) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to access your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await authVM.signOut();
    if (!mounted) return;
    context.go(RouteNames.roleSelection);
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: const Text(
          'RateBridge platform terms apply to all suppliers.\n'
          'Contact admin for details.',
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

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SupplierViewModel>();
    final authVM = context.watch<AuthViewModel>();
    final profile = viewModel.profile ?? authVM.user;
    final imageUrl = profile?.profileImageUrl;

    if (!_profileLoaded && viewModel.isLoading) {
      return Scaffold(
        backgroundColor: FieldColors.screenBackground,
        extendBodyBehindAppBar: true,
        appBar: _buildAppBar(profile, viewModel),
        bottomNavigationBar: const SupplierNavBar(currentIndex: 5),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final joinedYear = profile?.createdAt != null
        ? DateFormat('yyyy').format(profile!.createdAt)
        : '—';
    final avgRating = viewModel.averageRating;
    final materialsCount = viewModel.totalMaterialsCount;
    final ordersDone = _completedOrdersCount(viewModel);

    return Scaffold(
      backgroundColor: FieldColors.screenBackground,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(profile, viewModel),
      bottomNavigationBar: const SupplierNavBar(currentIndex: 5),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHeader(
              imageUrl: imageUrl,
              initials: _initials(profile?.name),
              businessName: profile?.name ?? 'Business Name',
              city: profile?.city ?? '—',
              joinedYear: joinedYear,
              isUploadingImage: _isUploadingImage,
              onPickImage: _pickProfileImage,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SellerStatsRow(
                materialsCount: materialsCount,
                avgRating: avgRating,
                ordersDone: ordersDone,
                onMaterialsTap: () => context.push(RouteNames.supplierMaterials),
                onOrdersTap: () => context.push(RouteNames.supplierOrders),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Form(
                key: _formKey,
                child: _BusinessInfoCard(
                  isEditing: _isEditing,
                  onToggleEdit: () => _toggleEditMode(profile),
                  onCancel: () => _cancelEdit(profile),
                  onSave: viewModel.isLoading
                      ? null
                      : () => _saveProfile(viewModel, profile),
                  isSaving: viewModel.isLoading,
                  nameController: _nameController,
                  phoneController: _phoneController,
                  cityController: _cityController,
                  businessType: _businessType,
                  onBusinessTypeChanged: (v) {
                    if (v != null) setState(() => _businessType = v);
                  },
                  viewName: _nameController.text.isNotEmpty
                      ? _nameController.text
                      : (profile?.name ?? '—'),
                  viewCity: _cityController.text.isNotEmpty
                      ? _cityController.text
                      : (profile?.city ?? '—'),
                  viewPhone: _phoneController.text.isNotEmpty
                      ? _phoneController.text
                      : (profile?.phone ?? '—'),
                  viewCnic: _maskedCnic(profile?.cnic ?? _cnicController.text),
                  viewBusinessType: _businessType,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _AccountSettingsCard(
                email: profile?.email ?? authVM.user?.email ?? '',
                onNotifications: _openNotificationPrefs,
                onChangePassword: () => _openChangePassword(
                  profile?.email ?? authVM.user?.email ?? '',
                ),
                onTerms: _showTermsDialog,
                onRatings: () => context.push(RouteNames.supplierRatings),
                onEarnings: () => context.push(RouteNames.supplierEarnings),
                onPartnerships: () =>
                    context.push(RouteNames.supplierMyCompanies),
                onFindCompanies: () =>
                    context.push(RouteNames.supplierCompanyDirectory),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _DangerZoneCard(
                onSignOut: () => _confirmSignOut(authVM),
              ),
            ),
            const SizedBox(height: 24),
            const _AppVersionFooter(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    UserModel? profile,
    SupplierViewModel viewModel,
  ) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leading: AppNavigation.leading(context, color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      title: Text(
        'My Profile',
        style: AppTextStyles.h3.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          tooltip: _isEditing ? 'Cancel edit' : 'Edit profile',
          onPressed: () => _toggleEditMode(profile),
          icon: Icon(
            _isEditing ? Icons.close : Icons.edit_outlined,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _ProfileHeader extends StatelessWidget {
  final String? imageUrl;
  final String initials;
  final String businessName;
  final String city;
  final String joinedYear;
  final bool isUploadingImage;
  final VoidCallback onPickImage;

  const _ProfileHeader({
    required this.imageUrl,
    required this.initials,
    required this.businessName,
    required this.city,
    required this.joinedYear,
    required this.isUploadingImage,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 140 + 48,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                height: 140,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [FieldColors.primaryNavy, FieldColors.primaryNavyDark],
                  ),
                ),
              ),
              Positioned(
                top: 140 - 48,
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
                        child: AppNetworkImage(
                          url: imageUrl,
                          fit: BoxFit.cover,
                          width: 96,
                          height: 96,
                          debugLabel: 'supplier-avatar',
                          loading: _initialsAvatar(),
                          fallback: _initialsAvatar(),
                        ),
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
          businessName,
          style: AppTextStyles.h3.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: FieldColors.primaryNavy,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            _InfoChip(
              icon: Icons.location_on_outlined,
              label: city,
            ),
            _InfoChip(
              icon: Icons.calendar_today_outlined,
              label: 'Joined $joinedYear',
            ),
          ],
        ),
      ],
    );
  }

  Widget _initialsAvatar() {
    return Container(
      color: FieldColors.accentAmber,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTextStyles.h2.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: FieldColors.primaryNavy,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: FieldColors.borderSubtle.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: FieldColors.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: FieldColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats
// ---------------------------------------------------------------------------

class _SellerStatsRow extends StatelessWidget {
  final int materialsCount;
  final double avgRating;
  final int ordersDone;
  final VoidCallback onMaterialsTap;
  final VoidCallback onOrdersTap;

  const _SellerStatsRow({
    required this.materialsCount,
    required this.avgRating,
    required this.ordersDone,
    required this.onMaterialsTap,
    required this.onOrdersTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: SupplierTheme.cardDecoration(),
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatSection(
                value: '$materialsCount',
                label: 'Materials',
                onTap: onMaterialsTap,
              ),
            ),
            _verticalDivider(),
            Expanded(
              child: _StatSection(
                value: '${avgRating.toStringAsFixed(1)} ★',
                label: 'Avg Rating',
                onTap: () => context.push(RouteNames.supplierRatings),
              ),
            ),
            _verticalDivider(),
            Expanded(
              child: _StatSection(
                value: '$ordersDone',
                label: 'Orders Done',
                onTap: onOrdersTap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      color: FieldColors.borderSubtle,
    );
  }
}

class _StatSection extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback onTap;

  const _StatSection({
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: AppTextStyles.h3.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: FieldColors.accentAmber,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Business information
// ---------------------------------------------------------------------------

class _BusinessInfoCard extends StatelessWidget {
  final bool isEditing;
  final VoidCallback onToggleEdit;
  final VoidCallback onCancel;
  final VoidCallback? onSave;
  final bool isSaving;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController cityController;
  final String businessType;
  final ValueChanged<String?> onBusinessTypeChanged;
  final String viewName;
  final String viewCity;
  final String viewPhone;
  final String viewCnic;
  final String viewBusinessType;

  const _BusinessInfoCard({
    required this.isEditing,
    required this.onToggleEdit,
    required this.onCancel,
    required this.onSave,
    required this.isSaving,
    required this.nameController,
    required this.phoneController,
    required this.cityController,
    required this.businessType,
    required this.onBusinessTypeChanged,
    required this.viewName,
    required this.viewCity,
    required this.viewPhone,
    required this.viewCnic,
    required this.viewBusinessType,
  });

  @override
  Widget build(BuildContext context) {
    final dropdownItems = _businessTypes.contains(businessType)
        ? _businessTypes
        : [..._businessTypes, businessType];

    return Container(
      decoration: SupplierTheme.cardDecoration(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Business Information',
                  style: AppTextStyles.h3.copyWith(
                    fontSize: 16,
                    color: FieldColors.primaryNavy,
                  ),
                ),
              ),
              IconButton(
                onPressed: onToggleEdit,
                icon: Icon(
                  isEditing ? Icons.close : Icons.edit_outlined,
                  size: 20,
                  color: FieldColors.primaryNavy,
                ),
                tooltip: isEditing ? 'Cancel edit' : 'Edit',
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isEditing) ...[
            _InfoRow(
              icon: Icons.store_outlined,
              label: 'Business Name',
              value: viewName,
            ),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'City',
              value: viewCity,
            ),
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: viewPhone,
            ),
            _InfoRow(
              icon: Icons.badge_outlined,
              label: 'CNIC',
              value: viewCnic,
              trailing: const Icon(Icons.lock_outline, size: 14, color: FieldColors.textMuted),
            ),
            _InfoRow(
              icon: Icons.construction_outlined,
              label: 'Business Type',
              value: viewBusinessType,
              showDivider: false,
            ),
          ] else ...[
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Business Name'),
              style: AppTextStyles.body,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: cityController,
              decoration: const InputDecoration(labelText: 'City'),
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
              style: AppTextStyles.body,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              readOnly: true,
              initialValue: viewCnic,
              decoration: const InputDecoration(
                labelText: 'CNIC',
                suffixIcon: Icon(Icons.lock_outline, size: 18),
                helperText: 'Cannot be changed after registration',
              ),
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: dropdownItems.contains(businessType)
                  ? businessType
                  : dropdownItems.first,
              decoration: const InputDecoration(labelText: 'Business Type'),
              items: dropdownItems
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: onBusinessTypeChanged,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: FieldColors.accentAmber,
                      foregroundColor: FieldColors.primaryNavy,
                    ),
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Changes'),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final bool showDivider;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: FieldColors.primaryNavy.withValues(alpha: 0.75)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: FieldColors.primaryNavy,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: FieldColors.borderSubtle.withValues(alpha: 0.8)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Account settings
// ---------------------------------------------------------------------------

class _AccountSettingsCard extends StatelessWidget {
  final String email;
  final VoidCallback onNotifications;
  final VoidCallback onChangePassword;
  final VoidCallback onTerms;
  final VoidCallback onRatings;
  final VoidCallback onEarnings;
  final VoidCallback onPartnerships;
  final VoidCallback onFindCompanies;

  const _AccountSettingsCard({
    required this.email,
    required this.onNotifications,
    required this.onChangePassword,
    required this.onTerms,
    required this.onRatings,
    required this.onEarnings,
    required this.onPartnerships,
    required this.onFindCompanies,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: SupplierTheme.cardDecoration(),
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Account Settings',
            style: AppTextStyles.h3.copyWith(
              fontSize: 16,
              color: FieldColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          _SettingsRow(
            icon: Icons.notifications_outlined,
            title: 'Notification Preferences',
            onTap: onNotifications,
          ),
          _SettingsRow(
            icon: Icons.lock_outline,
            title: 'Change Password',
            onTap: onChangePassword,
          ),
          _SettingsRow(
            icon: Icons.description_outlined,
            title: 'Terms & Conditions',
            onTap: onTerms,
          ),
          _SettingsRow(
            icon: Icons.star_outline,
            title: 'My Ratings & Reviews',
            onTap: onRatings,
          ),
          _SettingsRow(
            icon: Icons.handshake_outlined,
            title: 'My Companies & Partnerships',
            onTap: onPartnerships,
          ),
          _SettingsRow(
            icon: Icons.business_outlined,
            title: 'Find Companies',
            onTap: onFindCompanies,
          ),
          _SettingsRow(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Earnings & Commission',
            onTap: onEarnings,
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
        InkWell(
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
                    color: FieldColors.primaryNavy.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: FieldColors.primaryNavy),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 14,
                      color: FieldColors.primaryNavy,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: FieldColors.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, color: FieldColors.borderSubtle.withValues(alpha: 0.8)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Danger zone & footer
// ---------------------------------------------------------------------------

class _DangerZoneCard extends StatelessWidget {
  final VoidCallback onSignOut;

  const _DangerZoneCard({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FieldColors.surfaceWhite,
        borderRadius: BorderRadius.circular(FieldRadius.card),
        border: Border.all(color: FieldColors.borderSubtle),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: FieldColors.statusDanger, width: 3),
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(FieldRadius.card),
            bottomLeft: Radius.circular(FieldRadius.card),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Account',
                style: AppTextStyles.body.copyWith(
                  color: FieldColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: onSignOut,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
                        style: AppTextStyles.body.copyWith(
                          fontSize: 14,
                          color: FieldColors.statusDanger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppVersionFooter extends StatelessWidget {
  const _AppVersionFooter();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'RateBridge v1.0.0',
          style: AppTextStyles.caption.copyWith(
            fontSize: 12,
            color: FieldColors.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Supplier Portal',
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            color: FieldColors.textMuted.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
