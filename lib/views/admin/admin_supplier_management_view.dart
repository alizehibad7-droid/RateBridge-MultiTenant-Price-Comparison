import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../constants/app_colors.dart';

class AdminSupplierManagementView extends StatefulWidget {
  const AdminSupplierManagementView({super.key});

  @override
  State<AdminSupplierManagementView> createState() => _AdminSupplierManagementViewState();
}

class _AdminSupplierManagementViewState extends State<AdminSupplierManagementView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminVM = Provider.of<AdminViewModel>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Supplier Management", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Active'),
            Tab(text: 'Suspended'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSupplierList('pending', adminVM),
          _buildSupplierList('active', adminVM),
          _buildSupplierList('suspended', adminVM),
          _buildSupplierList('rejected', adminVM),
        ],
      ),
    );
  }

  Widget _buildSupplierList(String status, AdminViewModel adminVM) {
    return StreamBuilder<List<UserModel>>(
      stream: FirebaseFirestore.instance.collection('users')
          .where('role', isEqualTo: 'Supplier')
          .where('status', isEqualTo: status)
          .snapshots()
          .map((s) => s.docs.map((d) => UserModel.fromMap(d.data())).toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final suppliers = snapshot.data ?? [];

        if (suppliers.isEmpty) {
          return _buildEmptyState("No $status suppliers found.");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: suppliers.length,
          itemBuilder: (context, index) {
            final supplier = suppliers[index];
            return _buildSupplierCard(supplier, adminVM);
          },
        );
      },
    );
  }

  Widget _buildSupplierCard(UserModel supplier, AdminViewModel adminVM) {
    String status = (supplier.status ?? 'pending').toLowerCase();
    Color statusColor = _getStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: const Icon(Icons.storefront_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(supplier.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      if (supplier.businessType != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(supplier.businessType!, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
                _buildStatusBadge(status, statusColor),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(supplier.city, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 16),
                const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(DateFormat('MMM d, yyyy').format(supplier.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            if (supplier.phone.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(supplier.phone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            _buildActionButtons(supplier, adminVM),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(UserModel supplier, AdminViewModel adminVM) {
    String status = (supplier.status ?? 'pending').toLowerCase();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (status == 'pending') ...[
          ElevatedButton(
            onPressed: () => _confirmAction(
              context, 
              "Approve Supplier?", 
              "This will activate the supplier and grant access to their dashboard.",
              () => adminVM.approveSupplier(supplier.uid)
            ),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 0),
            child: const Text("Approve"),
          ),
          OutlinedButton(
            onPressed: () => _showRejectDialog(context, supplier.uid, adminVM),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
            child: const Text("Reject"),
          ),
        ],
        if (status == 'active') ...[
          OutlinedButton(
            onPressed: () => _confirmAction(
              context, 
              "Suspend Supplier?", 
              "The supplier will lose dashboard access immediately.",
              () => adminVM.suspendSupplier(supplier.uid)
            ),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.amber, side: const BorderSide(color: Colors.amber)),
            child: const Text("Suspend"),
          ),
        ],
        if (status == 'suspended' || status == 'rejected') ...[
          OutlinedButton(
            onPressed: () => _confirmAction(
              context, 
              "Activate Supplier?", 
              "The supplier will regain full access to the platform.",
              () => adminVM.approveSupplier(supplier.uid)
            ),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green)),
            child: const Text("Activate"),
          ),
        ],
        OutlinedButton(
          onPressed: () => _confirmAction(
            context, 
            "Delete Permanently?", 
            "This action is irreversible. All supplier records will be removed.",
            () => adminVM.deleteSupplierPermanently(supplier.uid),
            isDestructive: true
          ),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
          child: const Text("Delete"),
        ),
      ],
    );
  }

  void _confirmAction(BuildContext context, String title, String message, Future<void> Function() onConfirm, {bool isDestructive = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await onConfirm();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action completed successfully')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: Text("CONFIRM", style: TextStyle(color: isDestructive ? Colors.red : AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active': return Colors.green;
      case 'pending': return Colors.orange;
      case 'suspended': return Colors.red;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  void _showRejectDialog(BuildContext context, String uid, AdminViewModel adminVM) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reject Supplier Application"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: "Reason for rejection", border: OutlineInputBorder()),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () async {
              await adminVM.rejectSupplier(uid, reasonController.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("REJECT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_outlined, size: 64, color: Colors.grey.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
