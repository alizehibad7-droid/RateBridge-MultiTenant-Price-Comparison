import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../models/order_model.dart';
import '../../theme/admin_theme.dart';
import '../../widgets/admin/admin_widgets.dart';

class AdminOrdersView extends StatefulWidget {
  const AdminOrdersView({super.key});

  @override
  State<AdminOrdersView> createState() => _AdminOrdersViewState();
}

class _AdminOrdersViewState extends State<AdminOrdersView> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.screenBg,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFilters(),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final allOrders = docs.map((d) => OrderModel.fromMap(d.id, d.data() as Map<String, dynamic>)).toList();

                  final filteredOrders = allOrders.where((order) {
                    final matchesSearch = order.orderId.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                                        order.materialName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                                        order.supplierName.toLowerCase().contains(_searchQuery.toLowerCase());
                    final matchesStatus = _statusFilter == 'All' || order.status.toLowerCase() == _statusFilter.toLowerCase();
                    return matchesSearch && matchesStatus;
                  }).toList();

                  if (filteredOrders.isEmpty) {
                    return const AdminEmptyState(icon: Icons.shopping_cart_outlined, message: 'No orders found.');
                  }

                  return AdminCard(
                    padding: EdgeInsets.zero,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(AdminColors.navy.withValues(alpha: 0.03)),
                          columns: [
                            DataColumn(label: Text('Order ID', style: AdminTheme.sectionHeaderStyle())),
                            DataColumn(label: Text('Material', style: AdminTheme.sectionHeaderStyle())),
                            DataColumn(label: Text('Supplier', style: AdminTheme.sectionHeaderStyle())),
                            DataColumn(label: Text('Qty', style: AdminTheme.sectionHeaderStyle())),
                            DataColumn(label: Text('Total', style: AdminTheme.sectionHeaderStyle())),
                            DataColumn(label: Text('Status', style: AdminTheme.sectionHeaderStyle())),
                            DataColumn(label: Text('Date', style: AdminTheme.sectionHeaderStyle())),
                            DataColumn(label: Text('Action', style: AdminTheme.sectionHeaderStyle())),
                          ],
                          rows: filteredOrders.map((order) => DataRow(
                            cells: [
                              DataCell(Text('#${order.orderId.substring(0, 8)}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700))),
                              DataCell(Text(order.materialName, style: AdminTheme.bodyStyle())),
                              DataCell(Text(order.supplierName, style: AdminTheme.bodyStyle())),
                              DataCell(Text('${order.quantity} ${order.unit}', style: AdminTheme.bodyStyle())),
                              DataCell(Text('Rs ${order.totalAmount.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700))),
                              DataCell(StatusChip(status: order.status)),
                              DataCell(Text(DateFormat('MMM d, yyyy').format(order.createdAt), style: AdminTheme.bodyStyle())),
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined, size: 20),
                                  onPressed: () => _showOrderDetails(order),
                                ),
                              ),
                            ],
                          )).toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: AdminTheme.inputDecoration(
                hintText: 'Search by Order ID, Material or Supplier...',
                prefixIcon: const Icon(Icons.search, color: AdminColors.textGrey),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _statusFilter,
              decoration: AdminTheme.inputDecoration(labelText: 'Status'),
              items: ['All', 'Pending', 'Accepted', 'Delivered', 'Confirmed', 'Rejected', 'Cancelled']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) => setState(() => _statusFilter = val!),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order Details #${order.orderId.substring(0, 8)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailItem('Company ID', order.companyId),
              _detailItem('Field User', order.fieldUserName),
              _detailItem('Supplier', order.supplierName),
              _detailItem('Material', order.materialName),
              _detailItem('Quantity', '${order.quantity} ${order.unit}'),
              _detailItem('Unit Price', 'Rs ${order.unitPrice}'),
              _detailItem('Total Amount', 'Rs ${order.totalAmount}'),
              _detailItem('Status', order.status.toUpperCase()),
              _detailItem('Delivery Address', order.deliveryAddress),
              _detailItem('Created At', DateFormat('MMM d, yyyy HH:mm').format(order.createdAt)),
              if (order.notes != null) _detailItem('Notes', order.notes!),
              if (order.rejectionReason != null) _detailItem('Rejection Reason', order.rejectionReason!),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AdminTheme.sectionHeaderStyle().copyWith(fontSize: 10)),
          Text(value, style: AdminTheme.bodyStyle()),
          const Divider(height: 12),
        ],
      ),
    );
  }
}
