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
import 'admin_payment_queue_view.dart';
import 'admin_commission_ledger_view.dart';
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
      const AdminPaymentQueueView(embedded: true),
      const AdminFinanceView(),
      const AdminCommissionLedgerView(),
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
              onProfileTap: () => _onTabTapped(14),
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            Expanded(
              child: IndexedStack(
                index: _tabHistory.index,
                children: _screens,
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
                  onProfileTap: () => _onTabTapped(14),
                ),
                Expanded(
                  child: IndexedStack(
                    index: _tabHistory.index,
                    children: _screens,
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
      case 2: return 'CEOs & Companies';
      case 3: return 'Suppliers';
      case 4: return 'Orders';
      case 5: return 'Analytics';
      case 6: return 'Payment Queue';
      case 7: return 'Finance';
      case 8: return 'Commission';
      case 9: return 'Subscriptions';
      case 10: return 'Notifications';
      case 11: return 'Appeals';
      case 12: return 'Disputes';
      case 13: return 'Audit Logs';
      case 14: return 'Profile';
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
                _SidebarItem(icon: Icons.business_center_outlined, activeIcon: Icons.business_center_rounded, label: 'CEOs & Companies', isSelected: selectedIndex == 2, isCollapsed: isCollapsed, onTap: () => onItemSelected(2)),
                _SidebarItem(icon: Icons.storefront_outlined, activeIcon: Icons.storefront_rounded, label: 'Suppliers', isSelected: selectedIndex == 3, isCollapsed: isCollapsed, onTap: () => onItemSelected(3)),
                _SidebarItem(icon: Icons.shopping_cart_outlined, activeIcon: Icons.shopping_cart_rounded, label: 'Orders', isSelected: selectedIndex == 4, isCollapsed: isCollapsed, onTap: () => onItemSelected(4)),
                
                _SidebarSection(label: 'REPORTS', isCollapsed: isCollapsed),
                _SidebarItem(icon: Icons.analytics_outlined, activeIcon: Icons.analytics_rounded, label: 'Analytics', isSelected: selectedIndex == 5, isCollapsed: isCollapsed, onTap: () => onItemSelected(5)),
                _SidebarItem(icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded, label: 'Finance', isSelected: selectedIndex == 7, isCollapsed: isCollapsed, onTap: () => onItemSelected(7)),
                
                _SidebarSection(label: 'SYSTEM', isCollapsed: isCollapsed),
                _SidebarItem(icon: Icons.card_membership_outlined, activeIcon: Icons.card_membership_rounded, label: 'Subscriptions', isSelected: selectedIndex == 9, isCollapsed: isCollapsed, onTap: () => onItemSelected(9)),
                _SidebarItem(icon: Icons.notifications_active_outlined, activeIcon: Icons.notifications_active_rounded, label: 'Notifications', isSelected: selectedIndex == 10, isCollapsed: isCollapsed, onTap: () => onItemSelected(10)),
                _SidebarItem(icon: Icons.history_edu_outlined, activeIcon: Icons.history_edu_rounded, label: 'Appeals', isSelected: selectedIndex == 11, isCollapsed: isCollapsed, onTap: () => onItemSelected(11)),
                _SidebarItem(icon: Icons.gavel_outlined, activeIcon: Icons.gavel_rounded, label: 'Disputes', isSelected: selectedIndex == 12, isCollapsed: isCollapsed, onTap: () => onItemSelected(12)),
                _SidebarItem(icon: Icons.assignment_outlined, activeIcon: Icons.assignment_rounded, label: 'Audit Logs', isSelected: selectedIndex == 13, isCollapsed: isCollapsed, onTap: () => onItemSelected(13)),
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
      height: 70,
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
                    icon: const Icon(Icons.menu, color: AdminColors.navy),
                    onPressed: onMenuTap,
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    title, 
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, 
                      fontSize: screenWidth < 400 ? 16 : 20, 
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
                const VerticalDivider(width: 1, indent: 24, endIndent: 24, color: Color(0xFFE2E8F0)),
                SizedBox(width: screenWidth < 600 ? 8 : 16),
                PopupMenuButton<String>(
                  offset: const Offset(0, 50),
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
                          const Icon(Icons.person_outline, size: 20, color: AdminColors.navy),
                          const SizedBox(width: 12),
                          Text('Profile', style: AdminTheme.bodyStyle()),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          const Icon(Icons.logout_rounded, size: 20, color: AdminColors.red),
                          const SizedBox(width: 12),
                          Text('Logout', style: AdminTheme.bodyStyle(color: AdminColors.red)),
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
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: AdminColors.navy),
                            ),
                            Text('Administrator', style: AdminTheme.mutedStyle(size: 11)),
                          ],
                        ),
                        const SizedBox(width: 12),
                      ],
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AdminColors.amber.withValues(alpha: 0.1),
                        child: auth.user?.profileImageUrl != null
                          ? ClipOval(child: Image.network(auth.user!.profileImageUrl!, fit: BoxFit.cover))
                          : Text(
                              adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                              style: const TextStyle(color: AdminColors.navy, fontWeight: FontWeight.bold),
                            ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: AdminColors.textGrey, size: 20),
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
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC), 
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B), size: 20),
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
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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
    final bool isDesktop = screenWidth > 900;
    final bool isMobile = screenWidth < 600;

    return RefreshIndicator(
      color: AdminColors.navy,
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(isDesktop ? 32 : (isMobile ? 12 : 16)),
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
                                  Text('Overview', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 26, color: AdminColors.navy)),
                                  const SizedBox(height: 4),
                                  Text('Real-time ecosystem metrics and system operations.', style: AdminTheme.mutedStyle(size: 14)),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _refresh,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Refresh'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AdminColors.navy,
                                elevation: 0,
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            )
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Overview', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 20, color: AdminColors.navy)),
                            const SizedBox(height: 2),
                            Text('Real-time ecosystem metrics.', style: AdminTheme.mutedStyle(size: 11)),
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
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        );
                  }),
                  const SizedBox(height: 20),
                  
                  // Summary Cards - Elegant & Small
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 700 ? 2 : 1);
                      return GridView.count(
                        crossAxisCount: cols,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 10,
                        childAspectRatio: constraints.maxWidth > 400 ? 2.5 : 4.0,
                        children: [
                          _CompactStatWidget(label: 'Total Active Users', value: '${stats.totalUsers}', icon: Icons.people_outline, color: const Color(0xFF3B82F6), onTap: () => widget.onAction(1)),
                          _CompactStatWidget(label: 'Onboarded Firms', value: '${stats.totalCompanies}', icon: Icons.business_outlined, color: const Color(0xFF8B5CF6), onTap: () => widget.onAction(2)),
                          _CompactStatWidget(label: 'Active Contracts', value: '${stats.activeOrders}', icon: Icons.shopping_bag_outlined, color: const Color(0xFFF59E0B), onTap: () => widget.onAction(4)),
                          _CompactStatWidget(label: 'Completed Trades', value: '${stats.completedOrders}', icon: Icons.check_circle_outline_rounded, color: const Color(0xFF10B981), onTap: () => widget.onAction(4)),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final useRowLayout = constraints.maxWidth > 950;
                      final widgets = [
                        _RecentActivitySection(orders: adminVM.recentOrders, onAction: widget.onAction),
                        const SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(isMobile ? 16 : 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Platform Engines', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: isMobile ? 14 : 15, color: AdminColors.navy)),
                              const SizedBox(height: 16),
                              _HealthRow(label: 'Cloud Firestore', status: 'Healthy', color: const Color(0xFF10B981)),
                              const Divider(height: 20, color: Color(0xFFF1F5F9)),
                              _HealthRow(label: 'IAM Authentication', status: 'Healthy', color: const Color(0xFF10B981)),
                              const Divider(height: 20, color: Color(0xFFF1F5F9)),
                              _HealthRow(label: 'Trigger Functions', status: 'Active', color: const Color(0xFF10B981)),
                              const Divider(height: 20, color: Color(0xFFF1F5F9)),
                              _HealthRow(label: 'Cloud Storage', status: 'Healthy', color: const Color(0xFF10B981)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(isMobile ? 16 : 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Deep Data Analytics', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: isMobile ? 14 : 15, color: AdminColors.navy)),
                              const SizedBox(height: 6),
                              Text('Review user onboarding pipelines, regional procurement flow, and marketplace pricing metrics.', style: AdminTheme.mutedStyle(size: isMobile ? 12 : 13)),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => widget.onAction(5),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 12),
                                  ),
                                  child: Text('Launch Analytics Engine', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13, color: AdminColors.navy)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(isMobile ? 16 : 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Quick Operations', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: isMobile ? 14 : 15, color: AdminColors.navy)),
                              const SizedBox(height: 8),
                              _ShortcutItem(label: 'Financial Ledger & Ledger Sync', icon: Icons.account_balance_wallet_outlined, onTap: () => widget.onAction(7)),
                              _ShortcutItem(label: 'Corporate SaaS Subscription Plans', icon: Icons.card_membership_outlined, onTap: () => widget.onAction(9)),
                              _ShortcutItem(label: 'Security Audit & Event Log', icon: Icons.shield_outlined, onTap: () => widget.onAction(13)),
                            ],
                          ),
                        ),
                      ];

                      if (useRowLayout) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [widgets[0]],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                children: [
                                  widgets[2],
                                  const SizedBox(height: 16),
                                  widgets[3],
                                  const SizedBox(height: 16),
                                  widgets[4],
                                ],
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            widgets[0],
                            const SizedBox(height: 16),
                            widgets[2],
                            const SizedBox(height: 16),
                            widgets[3],
                            const SizedBox(height: 16),
                            widgets[4],
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 8 : 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 6 : 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(isMobile ? 6 : 10),
              ),
              child: Icon(icon, color: color, size: isMobile ? 16 : 20),
            ),
            SizedBox(width: isMobile ? 10 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isMobile ? 16 : 20,
                      fontWeight: FontWeight.w800,
                      color: AdminColors.navy,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: isMobile ? 8 : 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )
          ],
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Text('Live Procurement Logs', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: isMobile ? 14 : 15, color: AdminColors.navy)),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          orders.isEmpty
            ? const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No real-time procurement pipelines recorded.')))
            : Column(
                children: [
                  ...orders.take(isMobile ? 4 : 6).map((o) => Container(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF8FAFC))),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20, vertical: isMobile ? 0 : 4),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFF1F5F9), 
                        child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF475569), size: 16)
                      ),
                      title: Text('${o.materialName} — ${o.supplierName}', style: GoogleFonts.plusJakartaSans(color: AdminColors.navy, fontSize: isMobile ? 12 : 13, fontWeight: FontWeight.w600)),
                      subtitle: Text('ID: #${o.orderId.substring(0, 8).toUpperCase()} • ${DateFormat('MMM d, hh:mm a').format(o.createdAt)}', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFF94A3B8))),
                      trailing: Transform.scale(scale: isMobile ? 0.8 : 1.0, child: StatusChip(status: o.status)),
                      onTap: () => onAction(4),
                    ),
                  )),
                  Padding(
                    padding: EdgeInsets.all(isMobile ? 8 : 12),
                    child: Center(
                      child: TextButton(
                        onPressed: () => onAction(4), 
                        child: Text('View Full Procurement Center →', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: isMobile ? 12 : 13, color: AdminColors.amber))
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
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: isMobile ? 12 : 13, color: const Color(0xFF334155), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
          child: Text(status, style: GoogleFonts.plusJakartaSans(color: color, fontWeight: FontWeight.w700, fontSize: 9, letterSpacing: 0.3)),
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
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF64748B)),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: isMobile ? 12 : 13, color: const Color(0xFF334155), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.chevron_right, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
