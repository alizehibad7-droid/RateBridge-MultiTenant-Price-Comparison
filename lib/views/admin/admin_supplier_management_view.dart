import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/supplier_model.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../theme/admin_theme.dart';
import '../../utils/pakistan_validators.dart';
import '../../widgets/admin/admin_widgets.dart';
import '../../widgets/supplier_performance_scorecard.dart';

class AdminSupplierManagementView extends StatefulWidget {
  final bool embedded;

  const AdminSupplierManagementView({super.key, this.embedded = false});

  @override
  State<AdminSupplierManagementView> createState() =>
      _AdminSupplierManagementViewState();
}

class _AdminSupplierManagementViewState extends State<AdminSupplierManagementView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedSupplierUids = {};
  bool _isBulkProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedSupplierUids.clear());
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _bulkApprove(AdminViewModel adminVM) async {
    if (_selectedSupplierUids.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Approve Suppliers'),
        content: Text('Approve all ${_selectedSupplierUids.length} selected suppliers and grant dashboard access?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('APPROVE ALL', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isBulkProcessing = true);
    try {
      for (final uid in _selectedSupplierUids) {
        await adminVM.approveSupplier(uid);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully approved ${_selectedSupplierUids.length} suppliers')),
        );
        setState(() => _selectedSupplierUids.clear());
      }
    } finally {
      if (mounted) setState(() => _isBulkProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminVM = Provider.of<AdminViewModel>(context);

    final content = TabBarView(
      controller: _tabController,
      children: [
        _buildSupplierList('pending', adminVM),
        _buildSupplierList('active', adminVM),
        _buildSupplierList('suspended', adminVM),
        _buildSupplierList('rejected', adminVM),
      ],
    );

    return Scaffold(
      backgroundColor: AdminColors.screenBg,
      appBar: widget.embedded 
          ? null 
          : AdminAppBar(
              title: 'Supplier Management',
              bottom: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Pending'),
                  Tab(text: 'Active'),
                  Tab(text: 'Suspended'),
                  Tab(text: 'Rejected'),
                ],
              ),
            ),
      body: widget.embedded 
          ? Column(
              children: [
                Material(
                  color: AdminColors.navy,
                  child: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Pending'),
                      Tab(text: 'Active'),
                      Tab(text: 'Suspended'),
                      Tab(text: 'Rejected'),
                    ],
                  ),
                ),
                Expanded(child: content),
              ],
            )
          : content,
      floatingActionButton: (_tabController.index == 0 && _selectedSupplierUids.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: _isBulkProcessing ? null : () => _bulkApprove(adminVM),
              backgroundColor: AdminColors.amber,
              label: _isBulkProcessing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Approve Selected (${_selectedSupplierUids.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              icon: const Icon(Icons.done_all, color: Colors.white),
            )
          : null,
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
    final isPending = status == 'pending';
    final isSelected = _selectedSupplierUids.contains(supplier.uid);

    return AdminCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isPending)
                  Checkbox(
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedSupplierUids.add(supplier.uid);
                        } else {
                          _selectedSupplierUids.remove(supplier.uid);
                        }
                      });
                    },
                    activeColor: AdminColors.amber,
                  ),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AdminColors.amber.withValues(alpha: 0.1),
                  child: const Icon(Icons.storefront_rounded,
                      color: AdminColors.amber, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile?.name ?? supplier.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(supplier.email,
                          style: const TextStyle(
                              color: AdminColors.textGrey, fontSize: 12)),
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
                    size: 14, color: AdminColors.textGrey),
                const SizedBox(width: 4),
                Text(profile?.city ?? supplier.city,
                    style: const TextStyle(
                        fontSize: 12, color: AdminColors.textGrey)),
                const SizedBox(width: 16),
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: AdminColors.textGrey),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM d, yyyy').format(supplier.createdAt),
                  style: const TextStyle(
                      fontSize: 12, color: AdminColors.textGrey),
                ),
              ],
            ),
            const Divider(height: 28),
            SupplierPerformanceScorecard(
              supplierId: supplier.uid,
              averageRating: supplier.rating ?? 0.0,
            ),
            const SizedBox(height: 16),
            AdminApprovalSection(
              title: 'BUSINESS IDENTITY',
              children: [
                AdminDetailRow(label: 'Business name', value: profile?.name ?? supplier.name),
                AdminDetailRow(label: 'Business type', value: profile?.businessType ?? supplier.businessType ?? ''),
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
              title: 'DECLARED CATEGORIES',
              children: [
                AdminChipList(
                  items: profile?.declaredCategories ?? profile?.categories ?? const [],
                  color: AdminColors.navy,
                ),
              ],
            ),
            const Divider(height: 28),
            _buildActionButtons(supplier, adminVM),
          ],
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
            style: AdminTheme.primaryButtonStyle(height: 46),
            child: const Text('Approve'),
          ),
          OutlinedButton(
            onPressed: () => _showRejectDialog(context, supplier.uid, adminVM),
            style: AdminTheme.destructiveButtonStyle(),
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
            style: AdminTheme.destructiveButtonStyle(),
            child: const Text('Suspend'),
          ),
        ],
        if (status == 'suspended' || status == 'rejected') ...[
          ElevatedButton(
            onPressed: () => _confirmAction(
              context,
              'Activate Supplier?',
              'The supplier will regain full access to the platform.',
              () => adminVM.reactivateSupplier(supplier.uid),
            ),
            style: AdminTheme.primaryButtonStyle(height: 46),
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
          style: AdminTheme.destructiveButtonStyle(),
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
                color: isDestructive ? AdminColors.red : AdminColors.navy,
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
          decoration: AdminTheme.inputDecoration(
            labelText: 'Reason for rejection',
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
            child: Text(
              'REJECT',
              style: GoogleFonts.plusJakartaSans(
                color: AdminColors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
