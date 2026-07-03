// MVVM: View — no business logic

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../theme/ceo_theme.dart';
import '../../utils/formatters.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/order_model.dart';
import '../../widgets/ceo_nav_bar.dart';
import '../../widgets/ceo/ceo_widgets.dart';

const _statusTabs = [
  'All',
  'Awaiting Approval',
  'Pending',
  'Accepted',
  'In Progress',
  'Delivered',
  'Confirmed',
  'Rejected',
  'Cancelled',
];

class CeoOrdersView extends StatefulWidget {
  final int initialTab;

  const CeoOrdersView({super.key, this.initialTab = 0});

  @override
  State<CeoOrdersView> createState() => _CeoOrdersViewState();
}

class _CeoOrdersViewState extends State<CeoOrdersView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTab.clamp(0, _statusTabs.length - 1);
    _tabController = TabController(
      length: _statusTabs.length,
      vsync: this,
      initialIndex: initial,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<CeoViewModel>();
      if (vm.company == null) {
        vm.loadDashboard();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final vm = context.watch<CeoViewModel>();
    final companyId = vm.company?.id ?? authVm.companyId ?? '';

    return Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: CeoAppBar(
        title: 'Company Orders',
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
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
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load orders. Pull to refresh or try again shortly.',
                      style: CeoTheme.mutedStyle(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (companyId.isEmpty) {
                return Center(
                  child: Text(
                    'Company profile not loaded yet.',
                    style: CeoTheme.mutedStyle(),
                  ),
                );
              }
              final orders = snap.data ?? [];
              if (orders.isEmpty) {
                return Center(
                  child: Text(
                    'No orders found',
                    style: CeoTheme.mutedStyle(),
                  ),
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
    final awaitingApproval = isCeoAwaitingApproval(order.status);

    return GestureDetector(
      onTap: () => _showOrderDetail(context, order),
      child: AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.materialName,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: CeoColors.navy,
                    ),
                  ),
                ),
                CeoStatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Supplier: ${order.supplierName}',
              style: CeoTheme.mutedStyle(size: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Field User: ${order.fieldUserName}',
              style: CeoTheme.mutedStyle(size: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${order.quantity} ${order.unit}',
                  style: CeoTheme.mutedStyle(size: 12),
                ),
                const Spacer(),
                Text(
                  AppFormatters.formatPKRCurrency(order.totalAmount),
                  style: GoogleFonts.plusJakartaSans(
                    color: CeoColors.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              AppFormatters.date(order.createdAt),
              style: CeoTheme.mutedStyle(size: 11),
            ),
            if (awaitingApproval) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _confirmReject(context, vm, order),
                      style: CeoTheme.destructiveButtonStyle(height: 44),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => vm.approveOrder(order),
                      style: CeoTheme.primaryButtonStyle(height: 44),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
            if (canCancel) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _confirmCancel(context, vm, order),
                  child: Text(
                    'Cancel Order',
                    style: GoogleFonts.plusJakartaSans(
                      color: CeoColors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmReject(
      BuildContext context, CeoViewModel vm, OrderModel order) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject order?'),
        content: TextField(
          controller: reasonController,
          decoration: CeoTheme.inputDecoration(
            labelText: 'Reason (optional)',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            style: CeoTheme.destructiveButtonStyle(height: 40),
            onPressed: () {
              Navigator.pop(ctx);
              vm.rejectOrder(order, reason: reasonController.text);
            },
            child: const Text('Reject'),
          ),
        ],
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
          OutlinedButton(
            style: CeoTheme.destructiveButtonStyle(height: 40),
            onPressed: () {
              Navigator.pop(ctx);
              vm.cancelOrder(order.id,
                  context.read<AuthViewModel>().companyId ?? '');
            },
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );
  }

  void _showOrderDetail(BuildContext context, OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CeoColors.screenBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CeoColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Order #${order.id}',
              style: CeoTheme.titleStyle(size: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Center(child: CeoStatusBadge(status: order.status)),
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
                valueColor: CeoColors.navy),
            _detailSection('Commission',
                '-${AppFormatters.formatPKRCurrency(order.commissionAmount)}',
                valueColor: CeoColors.red),
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
          Text(label, style: CeoTheme.mutedStyle(size: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: valueColor ?? CeoColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
