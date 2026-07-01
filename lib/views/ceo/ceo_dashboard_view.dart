// MVVM: View — no business logic

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/ceo_nav_bar.dart';
import '../../widgets/status_badge.dart';
import '../../constants/app_colors.dart';
import '../../models/order_model.dart';

class CeoDashboardView extends StatefulWidget {
  const CeoDashboardView({super.key});

  @override
  State<CeoDashboardView> createState() => _CeoDashboardViewState();
}

class _CeoDashboardViewState extends State<CeoDashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CeoViewModel>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.read<AuthViewModel>();
    final companyId = authVm.user?.companyId ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Consumer<CeoViewModel>(
          builder: (_, vm, __) => Text(
            vm.company?.name ?? 'Dashboard',
            style: AppTextStyles.h3,
          ),
        ),
        actions: [
          _buildAppBarAction(
            icon: Icons.notifications_none_rounded,
            onPressed: () {},
          ),
        ],
      ),
      body: Consumer<CeoViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading && vm.company == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () => vm.loadDashboard(),
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
                      // Welcome
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: appCardDecoration(shadow: AppShadows.card),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back, ${vm.name}',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'You have $pendingOrders order approvals and '
                              '$pendingJoin supplier requests waiting.',
                              style: AppTextStyles.bodyMuted,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Stats row
                      Row(
                        children: [
                          Expanded(
                              child: _statCard('Field Users',
                                  '$fieldUserCount', Icons.engineering_outlined,
                                  color: AppColors.fieldAccent)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _statCard('Suppliers', '$supplierCount',
                                  Icons.store_outlined,
                                  color: AppColors.supplierAccent)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _statCard('Pending Reqs', '$pendingJoin',
                                  Icons.pending_actions,
                                  color: AppColors.warning)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Subscription card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: plan == 'Free'
                              ? AppColors.surface
                              : AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: plan == 'Free'
                              ? Border.all(
                                  color: AppColors.border, width: 0.5)
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  plan == 'Free'
                                      ? 'Free Plan'
                                      : '$plan Plan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: plan == 'Free'
                                        ? AppColors.textPrimary
                                        : Colors.white,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      context.go('/ceo/subscription'),
                                  child: Text(
                                    plan == 'Free' ? 'Upgrade' : 'Manage',
                                    style: TextStyle(
                                      color: plan == 'Free'
                                          ? AppColors.primary
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (expiresAt != null) ...[
                              Text(
                                'Expires: ${AppFormatters.date(expiresAt)}',
                                style: TextStyle(
                                  color: plan == 'Free'
                                      ? AppColors.textSecondary
                                      : Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (daysLeft / 30).clamp(0.0, 1.0),
                                  minHeight: 4,
                                  backgroundColor: Colors.white24,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Expiry warning
                      if (expiresAt != null && daysLeft < 7) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.dangerBg,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_outlined,
                                  color: AppColors.warning),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Subscription expiring in $daysLeft days — Renew now',
                                  style: const TextStyle(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    context.go('/ceo/subscription'),
                                child: const Text('Renew'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Quick Actions
                      Text('Quick Actions', style: AppTextStyles.h3),
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
                            icon: Icons.store_outlined,
                            title: 'My Suppliers',
                            color: AppColors.supplierAccent,
                            onTap: () => context.go('/ceo/suppliers'),
                          ),
                          _actionCard(
                            context,
                            icon: Icons.person_add_outlined,
                            title: 'Invite Suppliers',
                            color: AppColors.primary,
                            onTap: () => context.go('/ceo/invite'),
                          ),
                          _actionCard(
                            context,
                            icon: Icons.group_outlined,
                            title: 'Field Users',
                            color: AppColors.fieldAccent,
                            onTap: () => context.go('/ceo/field-users'),
                          ),
                          _actionCard(
                            context,
                            icon: Icons.receipt_outlined,
                            title: 'All Orders',
                            color: AppColors.adminAccent,
                            onTap: () => context.go('/ceo/orders'),
                          ),
                        ],
                      ),

                      // Recent orders
                      const SizedBox(height: 24),
                      Text('Recent Orders', style: AppTextStyles.h3),
                      const SizedBox(height: 8),
                      StreamBuilder<List<OrderModel>>(
                        stream: vm.watchCompanyOrders(companyId, 'All'),
                        builder: (context, snap) {
                          final orders = (snap.data ?? []).take(5).toList();
                          if (orders.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text('No orders yet',
                                  style: AppTextStyles.bodyMuted),
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

  Widget _buildAppBarAction({required IconData icon, required VoidCallback onPressed, Color color = AppColors.primary}) {
    return IconButton(
      icon: Icon(icon, color: color, size: 22),
      onPressed: onPressed,
    );
  }

  Widget _statCard(String label, String value, IconData icon,
      {Color color = AppColors.primary}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Widget _actionCard(BuildContext context,
      {required IconData icon,
      required String title,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: appCardDecoration(),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
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
      decoration: appCardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Text(order.materialName,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          _statusPill(order.status),
          const SizedBox(width: 8),
          Text(AppFormatters.formatPKRCurrency(order.totalAmount),
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.primary)),
        ],
      ),
    );
  }

  Widget _statusPill(String status) {
    final style = StatusBadgeStyle.of(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: style.bg,
          borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: style.fg, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}
