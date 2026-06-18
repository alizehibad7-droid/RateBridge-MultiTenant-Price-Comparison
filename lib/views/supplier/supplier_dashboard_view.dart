import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/order_model.dart';
import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/app_theme.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/supplier_nav_bar.dart';

class SupplierDashboardView extends StatefulWidget {
  const SupplierDashboardView({super.key});

  @override
  State<SupplierDashboardView> createState() => _SupplierDashboardViewState();
}

class _SupplierDashboardViewState extends State<SupplierDashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierViewModel>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<SupplierViewModel>(context);
    final authVM = Provider.of<AuthViewModel>(context);
    final user = authVM.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.name, style: AppTextStyles.h3),
            const Text(
              'SUPPLIER PORTAL',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: const SupplierNavBar(currentIndex: 0),
      body: viewModel.isLoading && viewModel.materials.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: viewModel.loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCompanySwitcher(viewModel),
                  const SizedBox(height: 20),
                  
                  // Dashboard Aggregates
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      StatCard(
                        label: 'Total Materials',
                        value: '${viewModel.totalMaterialsCount}',
                        icon: Icons.inventory_2_outlined,
                      ),
                      StatCard(
                        label: 'Avg. Rating',
                        value: viewModel.averageRating.toStringAsFixed(1),
                        icon: Icons.star_outline,
                        badge: 'Top 5%',
                        badgeColor: AppColors.success,
                      ),
                      StatCard(
                        label: 'Pending Orders',
                        value: '${viewModel.pendingOrdersCount}',
                        icon: Icons.pending_actions,
                        borderLeft: AppColors.warning,
                      ),
                      StatCard(
                        label: 'In Progress',
                        value: '${viewModel.inProgressOrdersCount}',
                        icon: Icons.local_shipping_outlined,
                        borderLeft: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildEarningsSection(viewModel),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Recent Orders', style: AppTextStyles.h3),
                      TextButton(
                        onPressed: () => context.go(RouteNames.supplierOrders),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (viewModel.orders.isEmpty)
                    _buildEmptyState('No orders found for this company.')
                  else
                    ...viewModel.orders.take(5).map((o) => _buildOrderRow(o)),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildCompanySwitcher(SupplierViewModel viewModel) {
    if (viewModel.companies.isEmpty) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: viewModel.selectedCompanyId,
          isExpanded: true,
          icon: const Icon(Icons.unfold_more, size: 20),
          items: viewModel.companies
              .map(
                (c) => DropdownMenuItem(
                  value: c.id,
                  child: Row(
                    children: [
                      const Icon(Icons.business, size: 18, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text(c.name, style: AppTextStyles.h3.copyWith(fontSize: 15)),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) viewModel.switchCompany(val);
          },
        ),
      ),
    );
  }

  Widget _buildEarningsSection(SupplierViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: appCardDecoration(
        borderColor: AppColors.primary.withOpacity(0.2),
      ).copyWith(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.05),
            Colors.white,
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Net Earnings', style: AppTextStyles.label),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.formatPKR(viewModel.netEarnings),
                    style: AppTextStyles.h2.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet, color: AppColors.primary),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat('Gross', CurrencyFormatter.formatPKR(viewModel.totalEarnings)),
              _buildMiniStat('Completed', '${viewModel.completedThisMonth} orders'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption),
        Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildOrderRow(OrderModel order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: appCardDecoration(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.receipt_long, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.materialName, style: AppTextStyles.h3.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  '${order.quantity} ${order.unit} • ${order.fieldUserName}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.formatPKR(order.totalAmount),
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              StatusBadge(label: order.status, status: order.status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: appCardDecoration(),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: AppColors.textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(msg, style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
