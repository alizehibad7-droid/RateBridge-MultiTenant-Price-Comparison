import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../models/order_model.dart';
import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/supplier_nav_bar.dart';

class SupplierOrdersView extends StatefulWidget {
  const SupplierOrdersView({super.key});

  @override
  State<SupplierOrdersView> createState() => _SupplierOrdersViewState();
}

class _SupplierOrdersViewState extends State<SupplierOrdersView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Pending', 'Accepted', 'Delivered', 'Confirmed', 'Rejected'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<SupplierViewModel>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Orders', style: AppTextStyles.h2),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      bottomNavigationBar: const SupplierNavBar(currentIndex: 2),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((status) => _buildOrderList(viewModel, status)).toList(),
      ),
    );
  }

  Widget _buildOrderList(SupplierViewModel viewModel, String tab) {
    final filteredOrders = viewModel.orders.where((o) {
      final status = o.status.toLowerCase();
      switch (tab) {
        case 'Pending': return status == 'pending';
        case 'Accepted': return status == 'accepted' || status == 'inprogress';
        case 'Delivered': return status == 'delivered';
        case 'Confirmed': return status == 'confirmed';
        case 'Rejected': return status == 'rejected' || status == 'cancelled';
        default: return false;
      }
    }).toList();

    if (viewModel.isLoading && filteredOrders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('No $tab orders found.', style: AppTextStyles.bodyMuted),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => viewModel.loadOrders(viewModel.selectedCompanyId!, null),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          return _buildOrderCard(viewModel, order, tab);
        },
      ),
    );
  }

  Widget _buildOrderCard(SupplierViewModel viewModel, OrderModel order, String tab) {
    final commission = order.totalAmount * 0.02; // Assuming 2% platform fee
    final netPayout = order.totalAmount - commission;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: appCardDecoration(shadow: AppShadows.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ID: #${order.orderId.substring(order.orderId.length - 6).toUpperCase()}',
                      style: AppTextStyles.label.copyWith(letterSpacing: 0.5),
                    ),
                    Text(
                      DateFormat('MMM dd, hh:mm a').format(order.createdAt),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(order.materialName, style: AppTextStyles.h3),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(order.fieldUserName, style: AppTextStyles.bodyMuted.copyWith(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('QUANTITY', style: AppTextStyles.label),
                        const SizedBox(height: 4),
                        Text('${order.quantity} ${order.unit}', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('NET PAYOUT', style: AppTextStyles.label),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.formatPKR(netPayout),
                          style: AppTextStyles.h3.copyWith(color: AppColors.success),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                StatusBadge(label: order.status.toUpperCase(), status: order.status),
                const Spacer(),
                TextButton(
                  onPressed: () => _showOrderDetail(viewModel, order),
                  child: const Text('DETAILS'),
                ),
              ],
            ),
          ),
          if (tab == 'Pending') ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showRejectDialog(viewModel, order),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        foregroundColor: AppColors.error,
                      ),
                      child: const Text('REJECT'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _confirmAccept(viewModel, order),
                      child: const Text('ACCEPT'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (tab == 'Accepted') ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _confirmDelivered(viewModel, order),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  child: const Text('MARK AS DELIVERED'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showOrderDetail(SupplierViewModel viewModel, OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Order Details', style: AppTextStyles.h2),
                      StatusBadge(label: order.status.toUpperCase(), status: order.status),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _detailItem('Material', order.materialName, Icons.inventory_2_outlined),
                  _detailItem('Quantity', '${order.quantity} ${order.unit}', Icons.straighten_outlined),
                  _detailItem('Unit Price', CurrencyFormatter.formatPKR(order.unitPrice), Icons.price_change_outlined),
                  const Divider(height: 48),
                  _detailItem('Customer', order.fieldUserName, Icons.person_outline),
                  _detailItem('Company', 'Usman Associates', Icons.business_outlined), // Should come from order or link
                  _detailItem('Delivery Address', order.deliveryAddress, Icons.location_on_outlined),
                  const Divider(height: 48),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount', style: AppTextStyles.body),
                      Text(CurrencyFormatter.formatPKR(order.totalAmount), style: AppTextStyles.h3),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Commission (2%)', style: AppTextStyles.bodyMuted),
                      Text('- ${CurrencyFormatter.formatPKR(order.totalAmount * 0.02)}', style: const TextStyle(color: AppColors.error)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.successBg, borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Net Payout', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                        Text(CurrencyFormatter.formatPKR(order.totalAmount * 0.98), style: AppTextStyles.h3.copyWith(color: AppColors.success)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => launchUrl(Uri.parse('tel:${order.fieldUserPhone}')),
                          icon: const Icon(Icons.phone_outlined, size: 18),
                          label: const Text('CALL'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => context.push('${RouteNames.supplierChat}/${order.orderId}'),
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text('CHAT'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(value, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAccept(SupplierViewModel viewModel, OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Order'),
        content: const Text('Confirm that you can fulfill this order. This will notify the field user.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.acceptOrder(order.orderId, order.companyId);
            },
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(SupplierViewModel viewModel, OrderModel order) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Order'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter reason for rejection'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isEmpty) return;
              Navigator.pop(context);
              await viewModel.rejectOrder(order.orderId, order.companyId, controller.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('REJECT'),
          ),
        ],
      ),
    );
  }

  void _confirmDelivered(SupplierViewModel viewModel, OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Delivered'),
        content: const Text('Has the shipment reached the site location?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.markDelivered(order.orderId, order.companyId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
  }
}
