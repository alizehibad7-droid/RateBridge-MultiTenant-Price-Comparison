import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:ratebridge/constants/route_names.dart';
import 'package:ratebridge/theme/admin_theme.dart';
import 'package:ratebridge/utils/app_navigation.dart';
import 'package:ratebridge/viewmodels/admin_viewmodel.dart';
import 'package:ratebridge/viewmodels/auth_viewmodel.dart';
import 'package:ratebridge/viewmodels/notification_viewmodel.dart';
import 'package:ratebridge/widgets/dashboard_hero_header.dart';
import 'package:ratebridge/models/category_model.dart';
import 'package:ratebridge/models/order_model.dart';

import 'admin_finance_view.dart';
import 'admin_ceo_management_view.dart';
import 'admin_profile_view.dart';
import 'admin_supplier_management_view.dart';
import 'admin_appeals_view.dart';
import 'admin_categories_view.dart';
import 'admin_dispute_list_view.dart';
import 'admin_audit_log_view.dart';
import 'admin_notifications_view.dart';
import 'admin_subscription_view.dart';
import 'admin_analytics_view.dart';
import 'admin_all_users_view.dart';
import 'admin_orders_view.dart';
import 'package:ratebridge/widgets/admin/admin_widgets.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({
    super.key,
    @visibleForTesting this.debugFirestore,
  });

  final FirebaseFirestore? debugFirestore;

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  final TabHistory _tabHistory = TabHistory();
  bool _isSidebarCollapsed = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _onTabTapped(int index) {
    if (_tabHistory.select(index)) setState(() {});
  }

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      _AdminHomeOverview(onAction: _onTabTapped),
      const AdminAllUsersView(),
      AdminCeoManagementView(embedded: true, debugFirestore: widget.debugFirestore),
      AdminSupplierManagementView(embedded: true, debugFirestore: widget.debugFirestore),
      const AdminOrdersView(),
      const AdminAnalyticsView(),
      const AdminFinanceView(),
      const AdminSubscriptionView(),
      const AdminNotificationsView(),
      const AdminAppealsView(),
      const AdminDisputeListView(),
      const AdminAuditLogView(),
      const AdminProfileView(), 
    ];
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    if (width >= 1024) {
      return _buildDesktopLayout(context);
    } else {
      return _buildResponsiveMobileLayout(context);
    }
  }

  Widget _buildResponsiveMobileLayout(BuildContext context) {
    final adminVM = context.watch<AdminViewModel>();
    final auth = context.watch<AuthViewModel>();
    final notifVM = context.watch<NotificationViewModel>();

    return TabHistoryPopScope(
      history: _tabHistory,
      onChanged: () => setState(() {}),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AdminColors.screenBg,
        drawer: Drawer(
          child: _AdminSidebar(
            selectedIndex: _tabHistory.index,
            isCollapsed: false,
            onItemSelected: (index) {
              _onTabTapped(index);
              _scaffoldKey.currentState?.closeDrawer();
            },
          ),
        ),
        body: Column(
          children: [
            _AdminTopBar(
              title: _getScreenTitle(_tabHistory.index),
              adminName: auth.user?.name ?? 'Admin',
              unreadNotifications: notifVM.unreadCount,
              isLoading: adminVM.isLoading,
              onProfileTap: () => _onTabTapped(12),
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            Expanded(
              child: ClipRect(
                child: IndexedStack(
                  index: _tabHistory.index,
                  sizing: StackFit.expand,
                  children: _screens,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final adminVM = context.watch<AdminViewModel>();
    final auth = context.watch<AuthViewModel>();
    final notifVM = context.watch<NotificationViewModel>();

    return Scaffold(
      backgroundColor: AdminColors.screenBg,
      body: Row(
        children: [
          _AdminSidebar(
            selectedIndex: _tabHistory.index,
            isCollapsed: _isSidebarCollapsed,
            onItemSelected: _onTabTapped,
          ),
          Expanded(
            child: Column(
              children: [
                _AdminTopBar(
                  title: _getScreenTitle(_tabHistory.index),
                  adminName: auth.user?.name ?? 'Admin',
                  unreadNotifications: notifVM.unreadCount,
                  isLoading: adminVM.isLoading,
                  onProfileTap: () => _onTabTapped(12),
                ),
                Expanded(
                  child: ClipRect(
                    child: IndexedStack(
                      index: _tabHistory.index,
                      sizing: StackFit.expand,
                      children: _screens,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getScreenTitle(int index) {
    switch (index) {
      case 0: return 'Dashboard';
      case 1: return 'Users';
      case 2: return 'Companies';
      case 3: return 'Suppliers';
      case 4: return 'Orders';
      case 5: return 'Analytics';
      case 6: return 'Finance';
      case 7: return 'Subscriptions';
      case 8: return 'Notifications';
      case 9: return 'Appeals';
      case 10: return 'Disputes';
      case 11: return 'Activity Logs';
      case 12: return 'Profile';
      default: return 'RateBridge Admin';
    }
  }
}

class _AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final bool isCollapsed;
  final Function(int) onItemSelected;

  const _AdminSidebar({
    required this.selectedIndex,
    required this.isCollapsed,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isCollapsed ? 80 : 260,
      color: const Color(0xFF0F172A), // Premium darker color palette
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildLogo(),
          const SizedBox(height: 32),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _SidebarSection(label: 'MAIN', isCollapsed: isCollapsed),
                _SidebarItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard_rounded, label: 'Dashboard', isSelected: selectedIndex == 0, isCollapsed: isCollapsed, onTap: () => onItemSelected(0)),
                
                _SidebarSection(label: 'MANAGEMENT', isCollapsed: isCollapsed),
                _SidebarItem(icon: Icons.people_outline, activeIcon: Icons.people_rounded, label: 'Users', isSelected: selectedIndex == 1, isCollapsed: isCollapsed, onTap: () => onItemSelected(1)),
                _SidebarItem(icon: Icons.business_center_outlined, activeIcon: Icons.business_center_rounded, label: 'Companies', isSelected: selectedIndex == 2, isCollapsed: isCollapsed, onTap: () => onItemSelected(2)),
                _SidebarItem(icon: Icons.storefront_outlined, activeIcon: Icons.storefront_rounded, label: 'Suppliers', isSelected: selectedIndex == 3, isCollapsed: isCollapsed, onTap: () => onItemSelected(3)),
                _SidebarItem(icon: Icons.shopping_cart_outlined, activeIcon: Icons.shopping_cart_rounded, label: 'Orders', isSelected: selectedIndex == 4, isCollapsed: isCollapsed, onTap: () => onItemSelected(4)),
                
                _SidebarSection(label: 'REPORTS', isCollapsed: isCollapsed),
                _SidebarItem(icon: Icons.analytics_outlined, activeIcon: Icons.analytics_rounded, label: 'Analytics', isSelected: selectedIndex == 5, isCollapsed: isCollapsed, onTap: () => onItemSelected(5)),
                _SidebarItem(icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded, label: 'Finance', isSelected: selectedIndex == 6, isCollapsed: isCollapsed, onTap: () => onItemSelected(6)),
                
                _SidebarSection(label: 'SYSTEM', isCollapsed: isCollapsed),
                _SidebarItem(icon: Icons.card_membership_outlined, activeIcon: Icons.card_membership_rounded, label: 'Subscriptions', isSelected: selectedIndex == 7, isCollapsed: isCollapsed, onTap: () => onItemSelected(7)),
                _SidebarItem(icon: Icons.notifications_active_outlined, activeIcon: Icons.notifications_active_rounded, label: 'Notifications', isSelected: selectedIndex == 8, isCollapsed: isCollapsed, onTap: () => onItemSelected(8)),
                _SidebarItem(icon: Icons.history_edu_outlined, activeIcon: Icons.history_edu_rounded, label: 'Appeals', isSelected: selectedIndex == 9, isCollapsed: isCollapsed, onTap: () => onItemSelected(9)),
                _SidebarItem(icon: Icons.gavel_outlined, activeIcon: Icons.gavel_rounded, label: 'Disputes', isSelected: selectedIndex == 10, isCollapsed: isCollapsed, onTap: () => onItemSelected(10)),
                _SidebarItem(icon: Icons.assignment_outlined, activeIcon: Icons.assignment_rounded, label: 'Activity Logs', isSelected: selectedIndex == 11, isCollapsed: isCollapsed, onTap: () => onItemSelected(11)),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset('assets/images/app_icon.png', width: 32, height: 32, errorBuilder: (_, __, ___) => const Icon(Icons.shield, color: AdminColors.amber, size: 32)),
        ),
        if (!isCollapsed) ...[
          const SizedBox(width: 12),
          Text(
            'RATEBRIDGE',
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 0.8),
          ),
        ],
      ],
    );
  }
}

class _SidebarSection extends StatelessWidget {
  final String label;
  final bool isCollapsed;
  const _SidebarSection({required this.label, required this.isCollapsed});

  @override
  Widget build(BuildContext context) {
    if (isCollapsed) return const Divider(color: Colors.white10, height: 24);
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 20, bottom: 8),
      child: Text(label, style: GoogleFonts.plusJakartaSans(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Tooltip(
        message: isCollapsed ? label : '',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(isSelected ? activeIcon : icon, color: isSelected ? AdminColors.amber : Colors.white60, size: 20),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        color: isSelected ? Colors.white : Colors.white60,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  final String title;
  final String adminName;
  final int unreadNotifications;
  final bool isLoading;
  final VoidCallback onProfileTap;
  final VoidCallback? onMenuTap;

  const _AdminTopBar({
    required this.title,
    required this.adminName,
    required this.unreadNotifications,
    required this.isLoading,
    required this.onProfileTap,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthViewModel>();
    final double screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: screenWidth < 600 ? 12 : 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                if (onMenuTap != null) ...[
                  IconButton(
                    icon: const Icon(Icons.menu, color: AdminColors.navy, size: 20),
                    onPressed: onMenuTap,
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    title, 
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, 
                      fontSize: screenWidth < 400 ? 15 : 18, 
                      color: AdminColors.navy
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _TopBarAction(
                  icon: Icons.notifications_none_rounded,
                  badge: unreadNotifications > 0 ? '$unreadNotifications' : null,
                  onTap: () => context.push(RouteNames.adminNotifications),
                ),
                SizedBox(width: screenWidth < 600 ? 8 : 16),
                const VerticalDivider(width: 1, indent: 20, endIndent: 20, color: Color(0xFFE2E8F0)),
                SizedBox(width: screenWidth < 600 ? 8 : 16),
                PopupMenuButton<String>(
                  offset: const Offset(0, 40),
                  onSelected: (value) async {
                    if (value == 'profile') {
                      onProfileTap();
                    } else if (value == 'logout') {
                      await auth.signOut();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, size: 18, color: AdminColors.navy),
                          const SizedBox(width: 12),
                          Text('Profile', style: AdminTheme.bodyStyle(size: 12)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          const Icon(Icons.logout_rounded, size: 18, color: AdminColors.red),
                          const SizedBox(width: 12),
                          Text('Logout', style: AdminTheme.bodyStyle(color: AdminColors.red, size: 12)),
                        ],
                      ),
                    ),
                  ],
                  child: Row(
                    children: [
                      if (screenWidth > 600) ...[
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              adminName,
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12, color: AdminColors.navy),
                            ),
                            Text('Administrator', style: AdminTheme.mutedStyle(size: 10)),
                          ],
                        ),
                        const SizedBox(width: 12),
                      ],
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AdminColors.amber.withValues(alpha: 0.1),
                        child: auth.user?.profileImageUrl != null
                          ? ClipOval(child: Image.network(auth.user!.profileImageUrl!, fit: BoxFit.cover))
                          : Text(
                              adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                              style: const TextStyle(color: AdminColors.navy, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: AdminColors.textGrey, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            const LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent, color: AdminColors.amber),
        ],
      ),
    );
  }
}

class _TopBarAction extends StatelessWidget {
  final IconData icon;
  final String? badge;
  final VoidCallback onTap;
  const _TopBarAction({required this.icon, this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC), 
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B), size: 18),
          ),
          if (badge != null)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AdminColors.red,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminHomeOverview extends StatefulWidget {
  final Function(int) onAction;
  const _AdminHomeOverview({required this.onAction});

  @override
  State<_AdminHomeOverview> createState() => _AdminHomeOverviewState();
}

class _AdminHomeOverviewState extends State<_AdminHomeOverview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthViewModel>().user?.uid;
      if (uid != null) {
        final notif = context.read<NotificationViewModel>();
        notif.loadNotifications(uid);
        notif.watchUnreadCount(uid);
      }
      context.read<AdminViewModel>().loadDashboardData();
    });
  }

  Future<void> _refresh() => context.read<AdminViewModel>().loadDashboardData();

  @override
  Widget build(BuildContext context) {
    final adminVM = context.watch<AdminViewModel>();
    final stats = adminVM.stats;

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 1100;

    return RefreshIndicator(
      color: AdminColors.navy,
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(isDesktop ? 24 : 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(builder: (context, constraints) {
                    final bool useRow = constraints.maxWidth > 600;
                    return useRow 
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Overview', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 22, color: AdminColors.navy)),
                                  const SizedBox(height: 2),
                                  Text('Real-time system overview.', style: AdminTheme.mutedStyle(size: 13)),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _refresh,
                              icon: const Icon(Icons.refresh_rounded, size: 14),
                              label: const Text('Refresh'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AdminColors.navy,
                                elevation: 0,
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            )
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Overview', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: AdminColors.navy)),
                            const SizedBox(height: 1),
                            Text('Real-time platform stats.', style: AdminTheme.mutedStyle(size: 11)),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _refresh,
                                icon: const Icon(Icons.refresh_rounded, size: 14),
                                label: const Text('Refresh'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AdminColors.navy,
                                  elevation: 0,
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                              ),
                            ),
                          ],
                        );
                  }),
                  const SizedBox(height: 20),
                  
                  // Summary Cards - Platform Stats (3 compact cards per row on Desktop)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final cols = w >= 720 ? 3 : (w >= 420 ? 2 : 1);
                      final cardHeight = w >= 720 ? 62.0 : (w >= 420 ? 58.0 : 56.0);
                      return GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisExtent: cardHeight,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        children: [
                          _CompactStatWidget(label: 'Total Users', value: '${stats.totalUsers}', icon: Icons.people_outline, color: const Color(0xFF3B82F6), onTap: () => widget.onAction(1)),
                          _CompactStatWidget(label: 'Total Companies', value: '${stats.totalCompanies}', icon: Icons.business_outlined, color: const Color(0xFF8B5CF6), onTap: () => widget.onAction(2)),
                          _CompactStatWidget(label: 'Pending Orders', value: '${stats.activeOrders}', icon: Icons.shopping_bag_outlined, color: const Color(0xFFF59E0B), onTap: () => widget.onAction(4)),
                          _CompactStatWidget(label: 'Completed Orders', value: '${stats.completedOrders}', icon: Icons.check_circle_outline_rounded, color: const Color(0xFF10B981), onTap: () => widget.onAction(4)),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 12),
                  
                  // Financial Summary Row (3 compact cards per row on Desktop)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final cols = w >= 720 ? 3 : (w >= 420 ? 2 : 1);
                      final cardHeight = w >= 720 ? 62.0 : (w >= 420 ? 58.0 : 56.0);
                      return GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisExtent: cardHeight,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        children: [
                          _CompactStatWidget(
                            label: 'Total Revenue', 
                            value: 'Rs ${stats.totalRevenue.toStringAsFixed(0)}', 
                            icon: Icons.payments_rounded, 
                            color: AdminColors.purple, 
                            onTap: () => widget.onAction(6)
                          ),
                          _CompactStatWidget(
                            label: 'Paid Commission', 
                            value: 'Rs ${stats.paidCommission.toStringAsFixed(0)}', 
                            icon: Icons.account_balance_wallet_rounded, 
                            color: AdminColors.green, 
                            onTap: () => widget.onAction(6)
                          ),
                          _CompactStatWidget(
                            label: 'Subscription Payouts', 
                            value: 'Rs ${stats.totalSubscriptionPayments.toStringAsFixed(0)}', 
                            icon: Icons.card_membership_rounded, 
                            color: AdminColors.navy, 
                            onTap: () => widget.onAction(6)
                          ),
                          _CompactStatWidget(
                            label: 'Pending Commission', 
                            value: 'Rs ${stats.pendingCommission.toStringAsFixed(0)}', 
                            icon: Icons.pending_actions_rounded, 
                            color: AdminColors.red, 
                            onTap: () => widget.onAction(6)
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final useThreeColumn = constraints.maxWidth > 1100;
                      
                      final activityCard = _RecentActivitySection(orders: adminVM.recentOrders, onAction: widget.onAction);
                      
                      final statusCard = Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AdminTheme.cardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('System Status', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: AdminColors.navy)),
                            const SizedBox(height: 12),
                            _HealthRow(label: 'Database', status: 'Healthy', color: const Color(0xFF10B981)),
                            const Divider(height: 16, color: Color(0xFFF1F5F9)),
                            _HealthRow(label: 'User Access', status: 'Healthy', color: const Color(0xFF10B981)),
                            const Divider(height: 16, color: Color(0xFFF1F5F9)),
                            _HealthRow(label: 'Stripe Webhooks', status: 'Active', color: const Color(0xFF10B981)),
                            const Divider(height: 16, color: Color(0xFFF1F5F9)),
                            _HealthRow(label: 'Automation', status: 'Active', color: const Color(0xFF10B981)),
                          ],
                        ),
                      );

                      final reportsCard = Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AdminTheme.cardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Reports', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: AdminColors.navy)),
                            const SizedBox(height: 4),
                            Text('Review platform growth.', style: AdminTheme.mutedStyle(size: 11)),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => widget.onAction(5),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                child: Text('Analytics', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 12, color: AdminColors.navy)),
                              ),
                            ),
                          ],
                        ),
                      );

                      final tasksCard = Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AdminTheme.cardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Quick Tasks', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: AdminColors.navy)),
                            const SizedBox(height: 6),
                            _ShortcutItem(label: 'Finance', icon: Icons.account_balance_wallet_outlined, onTap: () => widget.onAction(6)),
                            _ShortcutItem(label: 'Subscriptions', icon: Icons.card_membership_outlined, onTap: () => widget.onAction(7)),
                            _ShortcutItem(label: 'Logs', icon: Icons.shield_outlined, onTap: () => widget.onAction(11)),
                          ],
                        ),
                      );

                      if (useThreeColumn) {
                        return Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: activityCard),
                                const SizedBox(width: 16),
                                Expanded(child: statusCard),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: reportsCard),
                                const SizedBox(width: 16),
                                Expanded(child: tasksCard),
                                const SizedBox(width: 16),
                                const Expanded(child: SizedBox()), // Placeholder for balance if 3 in row is strict
                              ],
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            activityCard,
                            const SizedBox(height: 16),
                            statusCard,
                            const SizedBox(height: 16),
                            reportsCard,
                            const SizedBox(height: 16),
                            tasksCard,
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStatWidget extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CompactStatWidget({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 12,
            vertical: isMobile ? 6 : 8,
          ),
          decoration: AdminTheme.cardDecoration(),
          child: Row(
            children: [
              Container(
                width: isMobile ? 28 : 30,
                height: isMobile ? 28 : 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: isMobile ? 14 : 15),
              ),
              SizedBox(width: isMobile ? 8 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: isMobile ? 14 : 15,
                          fontWeight: FontWeight.w800,
                          color: AdminColors.navy,
                          height: 1.1,
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 9 : 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

class _RecentActivitySection extends StatelessWidget {
  final List<OrderModel> orders;
  final Function(int) onAction;
  const _RecentActivitySection({required this.orders, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Container(
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Text('New Orders', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: AdminColors.navy)),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          orders.isEmpty
            ? const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No new orders recorded.', style: TextStyle(fontSize: 12))))
            : Column(
                children: [
                  ...orders.take(isMobile ? 5 : 6).map((o) => Container(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF8FAFC))),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 0),
                      dense: true,
                      leading: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFFF1F5F9), 
                        child: Icon(Icons.shopping_bag_outlined, color: Color(0xFF475569), size: 14)
                      ),
                      title: Text('${o.materialName} — ${o.supplierName}', style: GoogleFonts.plusJakartaSans(color: AdminColors.navy, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('ID: #${o.orderId.substring(0, 8).toUpperCase()} • ${DateFormat('MMM d').format(o.createdAt)}', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: const Color(0xFF94A3B8))),
                      trailing: Transform.scale(scale: 0.8, child: StatusChip(status: o.status)),
                      onTap: () => onAction(4),
                    ),
                  )),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(
                      child: TextButton(
                        onPressed: () => onAction(4), 
                        child: Text('View All Orders →', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 12, color: AdminColors.amber))
                      ),
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  final String label;
  final String status;
  final Color color;
  const _HealthRow({required this.label, required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF334155), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
          child: Text(status, style: GoogleFonts.plusJakartaSans(color: color, fontWeight: FontWeight.w700, fontSize: 8, letterSpacing: 0.3)),
        ),
      ],
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ShortcutItem({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF334155), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.chevron_right, size: 12, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
