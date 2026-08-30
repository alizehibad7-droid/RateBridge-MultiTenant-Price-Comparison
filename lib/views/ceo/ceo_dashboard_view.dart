// MVVM: View — no business logic

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../constants/route_names.dart';
import '../../models/order_model.dart';
import '../../theme/ceo_theme.dart';
import '../../utils/formatters.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/notification_viewmodel.dart';
import '../../widgets/ceo_nav_bar.dart';
import '../../widgets/ceo/ceo_widgets.dart';

class CeoDashboardView extends StatefulWidget {
  const CeoDashboardView({super.key});

  @override
  State<CeoDashboardView> createState() => _CeoDashboardViewState();
}

class _CeoDashboardViewState extends State<CeoDashboardView> {
  bool _regeneratingCode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CeoViewModel>().loadDashboard();
    });
  }

  Future<void> _copyInviteCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code copied')),
    );
  }

  Future<void> _regenerateCode(CeoViewModel vm) async {
    setState(() => _regeneratingCode = true);
    await vm.regenerateInviteCode();
    if (mounted) setState(() => _regeneratingCode = false);
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.read<AuthViewModel>();
    final companyId = authVm.user?.companyId ?? '';

    return Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: CeoAppBar(
        title: context.select<CeoViewModel, String>(
          (vm) => vm.company?.name ?? 'Dashboard',
        ),
        showNotificationIcon: true,
      ),
      body: Consumer<CeoViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading && vm.company == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final inviteCode = vm.company?.inviteCode ?? 'RB-XXXXXX';

          return RefreshIndicator(
            onRefresh: () => vm.loadDashboard(),
            color: CeoColors.amber,
            child: StreamBuilder<Map<String, dynamic>>(
              stream: vm.watchDashboardStats(companyId),
              builder: (context, snapshot) {
                final stats = snapshot.data ?? {};
                final pendingOrders =
                    (stats['pendingOrderApprovals'] ?? 0) as int;
                final pendingJoin = (stats['pendingJoinCount'] ?? 0) as int;
                final fieldUserCount = (stats['fieldUserCount'] ?? 0) as int;
                final supplierCount =
                    (stats['activeSupplierCount'] ?? 0) as int;
                final plan = stats['plan'] ?? 'Free';
                final expiresAt = stats['expiresAt'] as DateTime?;
                final daysLeft = expiresAt != null
                    ? expiresAt.difference(DateTime.now()).inDays
                    : 0;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: CeoTheme.cardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.waving_hand_rounded, color: CeoColors.amber, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Welcome back, ${vm.name}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: CeoColors.navy,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You have $pendingOrders order approvals and '
                              '$pendingJoin supplier requests waiting.',
                              style: CeoTheme.mutedStyle(size: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      CeoInviteCodeCard(
                        inviteCode: inviteCode,
                        onCopy: () => _copyInviteCode(inviteCode),
                        onRegenerate: () => _regenerateCode(vm),
                        isRegenerating: _regeneratingCode,
                      ),
                      if (pendingOrders > 0) ...[
                        const SizedBox(height: 16),
                        CeoPendingApprovalBanner(
                          count: pendingOrders,
                          onTap: () => context.go(
                            '${RouteNames.ceoOrders}?tab=1',
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.15,
                        children: [
                          CeoStatCard(
                            icon: Icons.engineering_rounded,
                            value: '$fieldUserCount',
                            label: 'Field Users',
                            color: CeoColors.navy,
                          ),
                          CeoStatCard(
                            icon: Icons.store_rounded,
                            value: '$supplierCount',
                            label: 'Active Suppliers',
                            color: CeoColors.green,
                          ),
                          CeoStatCard(
                            icon: Icons.pending_actions_rounded,
                            value: '$pendingJoin',
                            label: 'Pending Requests',
                            color: CeoColors.amber,
                          ),
                          CeoStatCard(
                            icon: Icons.assignment_late_rounded,
                            value: '$pendingOrders',
                            label: 'Orders to Review',
                            color: CeoColors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SubscriptionCard(
                        plan: plan.toString(),
                        expiresAt: expiresAt,
                        daysLeft: daysLeft,
                      ),
                      if (expiresAt != null && daysLeft < 7) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: CeoColors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: CeoColors.amber),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Subscription expiring in $daysLeft days — Renew now',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: CeoColors.darkAmber,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    context.go(RouteNames.ceoSubscription),
                                child: const Text('Renew'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: CeoColors.navy, size: 20),
                          const SizedBox(width: 8),
                          const CeoSectionLabel('Quick Actions'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.4,
                        children: [
                          _actionCard(
                            context,
                            icon: Icons.store_rounded,
                            title: 'My Suppliers',
                            onTap: () => context.go(RouteNames.ceoMySuppliers),
                          ),
                          _actionCard(
                            context,
                            icon: Icons.person_add_rounded,
                            title: 'Invite Suppliers',
                            onTap: () => context.go(RouteNames.ceoInvite),
                          ),
                          _actionCard(
                            context,
                            icon: Icons.groups_rounded,
                            title: 'Field Users',
                            onTap: () => context.go(RouteNames.ceoFieldUsers),
                          ),
                          _actionCard(
                            context,
                            icon: Icons.receipt_long_rounded,
                            title: 'All Orders',
                            onTap: () => context.go(RouteNames.ceoOrders),
                          ),
                          _actionCard(
                            context,
                            icon: Icons.request_quote_rounded,
                            title: 'Bulk Quotes',
                            onTap: () => context.push(RouteNames.ceoRfqs),
                          ),
                          _actionCard(
                            context,
                            icon: Icons.report_problem_rounded,
                            title: 'Issues',
                            onTap: () => context.push(RouteNames.ceoDisputes),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.history_rounded, color: CeoColors.navy, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Recent Orders',
                            style: CeoTheme.titleStyle(size: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<OrderModel>>(
                        stream: vm.watchCompanyOrders(companyId, 'All'),
                        builder: (context, snap) {
                          final orders = (snap.data ?? []).take(5).toList();
                          if (orders.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'No orders yet',
                                style: CeoTheme.mutedStyle(),
                              ),
                            );
                          }
                          return Column(
                            children: orders
                                .map((order) => _orderRow(order))
                                .toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
      bottomNavigationBar: const CeoNavBar(currentIndex: 0),
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: CeoTheme.cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: CeoColors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: CeoColors.navy),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: CeoColors.navy,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderRow(OrderModel order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: CeoTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CeoColors.navy.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_bag_rounded, size: 16, color: CeoColors.navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              order.materialName,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w500,
                color: CeoColors.navy,
              ),
            ),
          ),
          CeoStatusBadge(status: order.status),
          const SizedBox(width: 12),
          Text(
            AppFormatters.formatPKRCurrency(order.totalAmount),
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: CeoColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final String plan;
  final DateTime? expiresAt;
  final int daysLeft;

  const _SubscriptionCard({
    required this.plan,
    required this.expiresAt,
    required this.daysLeft,
  });

  @override
  Widget build(BuildContext context) {
    final isFree = plan.toLowerCase() == 'free';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CeoTheme.cardDecoration(
        borderColor: isFree ? CeoColors.border : null,
      ).copyWith(
        color: isFree ? Colors.white : CeoColors.navy,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isFree ? Icons.eco_rounded : Icons.workspace_premium_rounded,
                    color: isFree ? CeoColors.navy : CeoColors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isFree ? 'Free Plan' : '$plan Plan',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: isFree ? CeoColors.navy : Colors.white,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => context.go(RouteNames.ceoSubscription),
                icon: Icon(
                  isFree ? Icons.upgrade_rounded : Icons.settings_rounded,
                  size: 16,
                  color: isFree ? CeoColors.amber : Colors.white,
                ),
                label: Text(
                  isFree ? 'Upgrade' : 'Manage',
                  style: TextStyle(
                    color: isFree ? CeoColors.amber : Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (expiresAt != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Text(
                'Expires: ${AppFormatters.date(expiresAt!)}',
                style: GoogleFonts.plusJakartaSans(
                  color: isFree ? CeoColors.textGrey : Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (daysLeft / 30).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor:
                    isFree ? CeoColors.border : Colors.white24,
                color: CeoColors.amber,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
