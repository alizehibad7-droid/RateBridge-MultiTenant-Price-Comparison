import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/supplier_model.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../constants/app_colors.dart';
import '../../utils/pakistan_validators.dart';
import '../../widgets/admin/admin_widgets.dart';

class AdminSupplierManagementView extends StatefulWidget {
  const AdminSupplierManagementView({super.key});

  @override
  State<AdminSupplierManagementView> createState() =>
      _AdminSupplierManagementViewState();
}

class _AdminSupplierManagementViewState extends State<AdminSupplierManagementView>
    with SingleTickerProviderStateMixin {
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
        title: const Text('Supplier Management',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
      stream: FirebaseFirestore.instance
          .collection('users')
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
          return AdminEmptyState(
            icon: Icons.storefront_outlined,
            message: 'No $status suppliers found.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: suppliers.length,
          itemBuilder: (context, index) {
            final supplier = suppliers[index];
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('suppliers')
                  .doc(supplier.uid)
                  .get(),
              builder: (context, profileSnap) {
                SupplierModel? profile;
                if (profileSnap.hasData && profileSnap.data!.exists) {
                  profile = SupplierModel.fromMap(
                    profileSnap.data!.data() as Map<String, dynamic>,
                  );
                }
                return _buildSupplierCard(supplier, profile, adminVM);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSupplierCard(
    UserModel supplier,
    SupplierModel? profile,
    AdminViewModel adminVM,
  ) {
    final status = (supplier.status ?? 'pending').toLowerCase();
    final businessName = profile?.name ?? supplier.name;
    final ownerName = profile?.ownerFullName ?? supplier.name;
    final businessType = profile?.businessType ?? supplier.businessType ?? '';
    final cnic = _formatCnic(profile?.cnicNumber ?? supplier.cnic);
    final address =
        profile?.businessAddress ?? supplier.address ?? '';
    final city = profile?.city ?? supplier.city;
    final rejectionReason =
        supplier.rejectionReason ?? profile?.rejectionReason ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.supplierAccent.withValues(alpha: 0.1),
                  child: const Icon(Icons.storefront_rounded,
                      color: AppColors.supplierAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(businessName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(supplier.email,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      if (businessType.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            businessType,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(city,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 16),
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM d, yyyy').format(supplier.createdAt),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            if (supplier.phone.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.phone_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(supplier.phone,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            const Divider(height: 28),
            AdminApprovalSection(
              title: 'BUSINESS IDENTITY',
              children: [
                AdminDetailRow(label: 'Business name', value: businessName),
                AdminDetailRow(label: 'Business type', value: businessType),
                AdminDetailRow(
                  label: 'Years in business',
                  value: profile?.yearsInBusiness?.toString() ?? '',
                ),
                AdminDetailRow(
                  label: 'Registration / NTN',
                  value: profile?.businessRegistrationNumber ?? '',
                ),
              ],
            ),
            const SizedBox(height: 16),
            AdminApprovalSection(
              title: 'OWNER / CONTACT',
              children: [
                AdminDetailRow(label: 'Owner full name', value: ownerName),
                AdminDetailRow(label: 'CNIC', value: cnic),
                const SizedBox(height: 4),
                AdminDocumentThumbnailRow(
                  documents: [
                    (label: 'CNIC Front', url: profile?.cnicFrontUrl),
                    (label: 'CNIC Back', url: profile?.cnicBackUrl),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            AdminApprovalSection(
              title: 'LOCATION & DELIVERY',
              children: [
                AdminDetailRow(label: 'City', value: city),
                AdminDetailRow(label: 'Address', value: address, maxLines: 5),
                const SizedBox(height: 4),
                const Text(
                  'Delivery coverage',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                AdminChipList(
                  items: profile?.deliveryCoverageAreas ?? const [],
                  color: AppColors.supplierAccent,
                ),
              ],
            ),
            const SizedBox(height: 16),
            AdminApprovalSection(
              title: 'BUSINESS PROOF',
              children: [
                AdminDocumentThumbnailRow(
                  documents: [
                    (label: 'Shop / warehouse', url: profile?.shopPhotoUrl),
                    (label: 'Business license', url: profile?.businessLicenseUrl),
                    (label: 'Certification', url: profile?.certificationUrl),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            AdminApprovalSection(
              title: 'DECLARED CATEGORIES',
              children: [
                AdminChipList(
                  items: profile?.declaredCategories ?? profile?.categories ?? const [],
                  color: AppColors.primary,
                ),
              ],
            ),
            if (status == 'rejected' && rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rejection reason',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(rejectionReason, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
            const Divider(height: 28),
            _buildActionButtons(supplier, adminVM),
          ],
        ),
      ),
    );
  }

  String _formatCnic(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    return PakistanValidators.formatCnic(raw);
  }

  Widget _buildActionButtons(UserModel supplier, AdminViewModel adminVM) {
    final status = (supplier.status ?? 'pending').toLowerCase();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (status == 'pending') ...[
          ElevatedButton(
            onPressed: () => _confirmAction(
              context,
              'Approve Supplier?',
              'This will activate the supplier and grant access to their dashboard.',
              () => adminVM.approveSupplier(supplier.uid),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Approve'),
          ),
          OutlinedButton(
            onPressed: () => _showRejectDialog(context, supplier.uid, adminVM),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            child: const Text('Reject'),
          ),
        ],
        if (status == 'active') ...[
          OutlinedButton(
            onPressed: () => _confirmAction(
              context,
              'Suspend Supplier?',
              'The supplier will lose dashboard access immediately.',
              () => adminVM.suspendSupplier(supplier.uid),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amber,
              side: const BorderSide(color: Colors.amber),
            ),
            child: const Text('Suspend'),
          ),
        ],
        if (status == 'suspended' || status == 'rejected') ...[
          OutlinedButton(
            onPressed: () => _confirmAction(
              context,
              'Activate Supplier?',
              'The supplier will regain full access to the platform.',
              () => adminVM.approveSupplier(supplier.uid),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: const BorderSide(color: Colors.green),
            ),
            child: const Text('Activate'),
          ),
        ],
        OutlinedButton(
          onPressed: () => _confirmAction(
            context,
            'Delete Permanently?',
            'This action is irreversible. All supplier records will be removed.',
            () => adminVM.deleteSupplierPermanently(supplier.uid),
            isDestructive: true,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }

  void _confirmAction(
    BuildContext context,
    String title,
    String message,
    Future<void> Function() onConfirm, {
    bool isDestructive = false,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await onConfirm();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Action completed successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text(
              'CONFIRM',
              style: TextStyle(
                color: isDestructive ? Colors.red : AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(
    BuildContext context,
    String uid,
    AdminViewModel adminVM,
  ) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Supplier Application'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            border: OutlineInputBorder(),
            hintText: 'Shown to the applicant',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              await adminVM.rejectSupplier(uid, reason);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('REJECT',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
