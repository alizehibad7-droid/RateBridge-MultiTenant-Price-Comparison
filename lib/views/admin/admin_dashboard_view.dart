import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/route_names.dart';
import '../../theme/admin_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../viewmodels/notification_viewmodel.dart';
import '../../repositories/user_repository.dart';
import '../../services/cloudinary_service.dart';

import 'admin_categories_view.dart';
import 'admin_finance_view.dart';
import 'admin_ceo_management_view.dart';
import 'admin_supplier_management_view.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      _AdminHomeOverview(onAction: _onTabTapped),
      const AdminSupplierManagementView(embedded: true),
      const AdminFinanceView(),
      const AdminCeoManagementView(embedded: true),
      _AdminProfileView(onAction: _onTabTapped),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AdminViewModel>().isLoading;

    return Scaffold(
      backgroundColor: AdminColors.screenBg,
      appBar: AdminAppBar(
        title: 'RateBridge Admin',
        bottom: isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: AdminColors.amber,
                ),
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.storefront_outlined),
              activeIcon: Icon(Icons.storefront_rounded),
              label: 'Suppliers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Finance',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.business_outlined),
              activeIcon: Icon(Icons.business_rounded),
              label: 'CEOs',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminHomeOverview extends StatelessWidget {
  final Function(int) onAction;
  const _AdminHomeOverview({required this.onAction});

  @override
  Widget build(BuildContext context) {
    final adminVM = context.watch<AdminViewModel>();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AdminSectionLabel('Command Center'),
                const SizedBox(height: 8),
                Text(
                  'Operational Pulse',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.navy,
                  ),
                ),
                const SizedBox(height: 24),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    StreamBuilder<int>(
                      stream: adminVM.watchPendingUsersCount(),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return _buildStatCard(
                          'Pending Approval',
                          '$count',
                          Icons.how_to_reg_outlined,
                          AdminColors.amber,
                          isBadge: count > 0,
                        );
                      },
                    ),
                    StreamBuilder<int>(
                      stream: adminVM.watchActiveUsersCount(),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return _buildStatCard(
                          'Active Users',
                          '$count',
                          Icons.people_outline,
                          AdminColors.navy,
                        );
                      },
                    ),
                    StreamBuilder<int>(
                      stream: adminVM.watchSuspendedUsersCount(),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return _buildStatCard(
                          'Suspended',
                          '$count',
                          Icons.block_flipped,
                          AdminColors.red,
                        );
                      },
                    ),
                    _buildStatCard(
                      'Revenue',
                      'Active',
                      Icons.payments_outlined,
                      AdminColors.green,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AdminSectionLabel('Quick Actions'),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    _buildActionCard(
                      'Review\nCEOs',
                      Icons.person_add_alt_1_outlined,
                      () => onAction(3),
                    ),
                    _buildActionCard(
                      'Review\nSuppliers',
                      Icons.store_outlined,
                      () => onAction(1),
                    ),
                    _buildActionCard(
                      'Finance',
                      Icons.account_balance_wallet_outlined,
                      () => onAction(2),
                    ),
                    _buildActionCard(
                      'Dispute\nCenter',
                      Icons.gavel_outlined,
                      () => context.push(RouteNames.adminDisputes),
                    ),
                    _buildActionCard(
                      'Admin\nProfile',
                      Icons.person_outline,
                      () => onAction(4),
                    ),
                    _buildActionCard(
                      'Manage\nTaxonomy',
                      Icons.category_outlined,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AdminTheme.wrap(const AdminCategoriesView()),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isBadge = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              if (isBadge)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AdminColors.red,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AdminColors.navy,
            ),
          ),
          Text(title, style: AdminTheme.mutedStyle(size: 10)),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: AdminTheme.cardDecoration(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AdminColors.navy, size: 22),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AdminColors.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminProfileView extends StatefulWidget {
  final Function(int) onAction;
  const _AdminProfileView({required this.onAction});

  @override
  State<_AdminProfileView> createState() => _AdminProfileViewState();
}

class _AdminProfileViewState extends State<_AdminProfileView> {
  bool _isUploadingImage = false;

  Future<void> _pickProfileImage(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1000,
      imageQuality: 80,
    );

    if (pickedFile == null || !mounted) return;

    setState(() => _isUploadingImage = true);

    try {
      final bytes = await pickedFile.readAsBytes();
      final url = await CloudinaryService.uploadImageBytes(
        bytes: bytes,
        folder: 'ratebridge/profiles',
        filename: 'admin_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (url != null && mounted) {
        final authVM = context.read<AuthViewModel>();
        final uid = authVM.user?.uid;
        if (uid != null) {
          await context.read<UserRepository>().updateUserDoc(uid, {
            'profileImageUrl': url,
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload photo')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final user = authVM.user;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // A. Admin Profile Header
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _isUploadingImage ? null : () => _pickProfileImage(context),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AdminColors.navy,
                      backgroundImage: user?.profileImageUrl != null
                          ? NetworkImage(user!.profileImageUrl!)
                          : null,
                      child: user?.profileImageUrl == null
                          ? const Icon(
                              Icons.admin_panel_settings,
                              size: 40,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    if (_isUploadingImage)
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.black26,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AdminColors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 14,
                          color: AdminColors.navy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user?.name ?? 'Platform Administrator',
                style: AdminTheme.titleStyle(size: 20),
              ),
              const SizedBox(height: 8),
              _buildStatusBadge(user?.status ?? 'active'),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // B. Admin Account Information
        const AdminSectionLabel('Account Information'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AdminTheme.cardDecoration(),
          child: Column(
            children: [
              _buildInfoRow('Email', user?.email ?? 'N/A'),
              _buildInfoRow('Role', user?.role ?? 'Administrator'),
              _buildInfoRow('Status', (user?.status ?? 'active').toUpperCase()),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // C. Admin Management Shortcuts
        const AdminSectionLabel('Platform Management'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildShortcutItem(
              context,
              'Finance',
              'Payments & Ledger',
              Icons.account_balance_wallet_outlined,
              () => widget.onAction(2),
            ),
            _buildShortcutItem(
              context,
              'Taxonomy',
              'Categories',
              Icons.category_outlined,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminTheme.wrap(const AdminCategoriesView()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // H. Admin Preferences
        const AdminSectionLabel('Preferences'),
        const SizedBox(height: 12),
        Container(
          decoration: AdminTheme.cardDecoration(),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.notifications_none,
                  color: AdminColors.navy,
                ),
                title: const Text('Notifications'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(RouteNames.adminNotifications),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.language, color: AdminColors.navy),
                title: const Text('Language'),
                trailing: Text('English', style: AdminTheme.mutedStyle()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => authVM.signOut(),
            style: AdminTheme.destructiveButtonStyle(height: 52),
            child: const Text('Logout Session'),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    final colors = AdminTheme.statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: AdminTheme.bodyStyle(color: colors.fg).copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AdminTheme.mutedStyle(size: 14)),
          Text(
            value,
            style: AdminTheme.bodyStyle().copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutItem(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AdminTheme.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AdminColors.navy, size: 24),
            const SizedBox(height: 4),
            Text(
              title,
              style: AdminTheme.bodyStyle().copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            Text(subtitle, style: AdminTheme.mutedStyle(size: 10)),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderView extends StatelessWidget {
  final String title;
  const _PlaceholderView({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          color: AdminColors.textGrey,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
