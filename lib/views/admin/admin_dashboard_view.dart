import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../constants/route_names.dart';
import '../../theme/admin_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../viewmodels/notification_viewmodel.dart';
import '../../widgets/notification_badge_icon.dart';

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
      const _PlaceholderView(title: 'Global Orders Monitor'),
      const AdminFinanceView(),
      const AdminCeoManagementView(embedded: true),
      const _AdminProfileView(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AdminViewModel>().isLoading;
    final notifVM = context.watch<NotificationViewModel>();

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
        actions: [
          NotificationBadgeIcon(
            unreadCount: notifVM.unreadCount,
            iconColor: Colors.white,
            onPressed: () => context.push(RouteNames.adminNotifications),
          ),
          const SizedBox(width: 8),
        ],
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
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2_rounded),
              label: 'Orders',
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
                      () => onAction(4),
                    ),
                    _buildActionCard(
                      'Review\nSuppliers',
                      Icons.store_outlined,
                      () => onAction(1),
                    ),
                    _buildActionCard(
                      'Global\nOrders',
                      Icons.monitor_heart_outlined,
                      () => onAction(2),
                    ),
                    _buildActionCard(
                      'Commission\nLedger',
                      Icons.receipt_long_outlined,
                      () => onAction(3),
                    ),
                    _buildActionCard(
                      'Admin\nProfile',
                      Icons.person_outline,
                      () => onAction(5),
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

class _AdminProfileView extends StatelessWidget {
  const _AdminProfileView();

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: AdminColors.navy,
            child: Icon(
              Icons.admin_panel_settings,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            authVM.user?.name ?? 'Admin',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AdminColors.navy,
            ),
          ),
          Text(
            authVM.user?.email ?? '',
            style: AdminTheme.mutedStyle(),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => authVM.signOut(),
              style: AdminTheme.destructiveButtonStyle(height: 52),
              child: const Text('Logout Session'),
            ),
          ),
        ],
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
