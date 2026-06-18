// MVVM: View — no business logic

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/order_model.dart';
import '../../widgets/ceo_nav_bar.dart';
import '../../widgets/status_badge.dart';
import '../../constants/app_colors.dart';

const _statusTabs = ['All', 'Pending', 'Accepted', 'In Progress', 'Delivered', 'Confirmed', 'Rejected', 'Cancelled'];

class CeoOrdersView extends StatefulWidget {
  const CeoOrdersView({super.key});

  @override
  State<CeoOrdersView> createState() => _CeoOrdersViewState();
}

class _CeoOrdersViewState extends State<CeoOrdersView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: _statusTabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyId =
        context.read<AuthViewModel>().companyId ?? '';
    final vm = context.read<CeoViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Company Orders'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: _statusTabs.map((s) => Tab(text: s)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _statusTabs.map((status) {
          return StreamBuilder<List<OrderModel>>(
            stream: vm.watchCompanyOrders(companyId, status),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final orders = snap.data ?? [];
              if (orders.isEmpty) {
                return const Center(
                  child: Text('No orders found',
                      style: AppTextStyles.bodyMuted),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) =>
                    _orderCard(context, vm, orders[i]),
              );
            },
          );
        }).toList(),
      ),
      bottomNavigationBar: const CeoNavBar(currentIndex: 4),
    );
  }

  Widget _orderCard(
      BuildContext context, CeoViewModel vm, OrderModel order) {
    final canCancel = order.status == 'pending' || order.status == 'accepted';

    return GestureDetector(
      onTap: () => _showOrderDetail(context, order),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: appCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.materialName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
                _statusPill(order.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Supplier: ${order.supplierName}  ·  '
              'Field User: ${order.fieldUserName}',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${order.quantity} ${order.unit}',
                  style: AppTextStyles.bodyMuted,
                ),
                const Spacer(),
                Text(
                  AppFormatters.formatPKRCurrency(order.totalAmount),
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
                const SizedBox(width: 10),
                Text(AppFormatters.date(order.createdAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
            if (canCancel) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _confirmCancel(context, vm, order),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger),
                  child: const Text('Cancel Order'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmCancel(
      BuildContext context, CeoViewModel vm, OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel order?'),
        content: Text(
            'Are you sure you want to cancel order #${order.id}? '
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('No, keep it')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              vm.cancelOrder(order.id,
                  context.read<AuthViewModel>().companyId ?? '');
            },
            child: const Text('Yes, cancel', style: AppTextStyles.button),
          ),
        ],
      ),
    );
  }

  void _showOrderDetail(BuildContext context, OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Order #${order.id}',
                style: AppTextStyles.h2,
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Center(child: _statusPill(order.status)),
            const SizedBox(height: 20),
            _detailSection('Material', order.materialName),
            _detailSection('Quantity', '${order.quantity} ${order.unit}'),
            _detailSection('Supplier', order.supplierName),
            _detailSection('Field User', order.fieldUserName),
            _detailSection('Delivery Address', order.deliveryAddress),
            const Divider(height: 24),
            _detailSection('Unit Price',
                AppFormatters.formatPKRCurrency(order.unitPrice)),
            _detailSection('Total',
                AppFormatters.formatPKRCurrency(order.totalAmount),
                valueColor: AppColors.primary),
            _detailSection('Commission',
                '-${AppFormatters.formatPKRCurrency(order.commissionAmount)}',
                valueColor: AppColors.danger),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _detailSection(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMuted),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _statusPill(String status) {
    final style = StatusBadgeStyle.of(status);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: style.bg,
          borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: style.fg,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}
