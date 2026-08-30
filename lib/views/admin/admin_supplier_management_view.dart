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
        title: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: AdminColors.navy),
            const SizedBox(width: 10),
            const Text('Bulk Approval'),
          ],
        ),
        content: Text('Approve all ${_selectedSupplierUids.length} selected suppliers and grant dashboard access?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: const Text('APPROVE ALL'),
            style: AdminTheme.primaryButtonStyle(height: 40),
          ),
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
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Successfully approved ${_selectedSupplierUids.length} suppliers'),
              ],
            ),
          ),
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
                indicatorColor: AdminColors.amber,
                indicatorWeight: 3,
                labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 13),
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
                    indicatorColor: AdminColors.amber,
                    indicatorWeight: 3,
                    labelColor: AdminColors.amber,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12),
                    unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 12),
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
              backgroundColor: AdminColors.navy,
              label: _isBulkProcessing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Approve Selected (${_selectedSupplierUids.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              icon: const Icon(Icons.verified_user_rounded, color: Colors.white),
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
            icon: _emptyIcon(status),
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

  IconData _emptyIcon(String status) {
    switch(status) {
      case 'pending': return Icons.person_search_rounded;
      case 'active': return Icons.storefront_rounded;
      case 'suspended': return Icons.block_rounded;
      default: return Icons.domain_disabled_rounded;
    }
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
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AdminColors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.store_rounded,
                      color: AdminColors.amber, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile?.name ?? supplier.name,
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700, fontSize: 16, color: AdminColors.navy)),
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 12, color: AdminColors.textGrey),
                          const SizedBox(width: 4),
                          Text(supplier.email,
                              style: const TextStyle(
                                  color: AdminColors.textGrey, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 12),
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
            const Divider(height: 32),
            SupplierPerformanceScorecard(
              supplierId: supplier.uid,
              averageRating: supplier.rating ?? 0.0,
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 20),
            AdminApprovalSection(
              title: 'DECLARED CATEGORIES',
              children: [
                AdminChipList(
                  items: profile?.declaredCategories ?? profile?.categories ?? const [],
                  color: AdminColors.navy,
                ),
              ],
            ),
            const Divider(height: 32),
            _buildActionButtons(supplier, adminVM),
          ],
        ),
    );
  }

  Widget _buildActionButtons(UserModel supplier, AdminViewModel adminVM) {
    final status = (supplier.status ?? 'pending').toLowerCase();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (status == 'pending') ...[
          ElevatedButton.icon(
            onPressed: () => _confirmAction(
              context,
              'Approve Supplier?',
              'This will activate the supplier and grant access to their dashboard.',
              () => adminVM.approveSupplier(supplier.uid),
              confirmIcon: Icons.check_circle_rounded,
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Approve'),
            style: AdminTheme.primaryButtonStyle(height: 46).copyWith(
              minimumSize: WidgetStateProperty.all(const Size(140, 46)),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _showRejectDialog(context, supplier.uid, adminVM),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Reject'),
            style: AdminTheme.destructiveButtonStyle().copyWith(
              minimumSize: WidgetStateProperty.all(const Size(120, 46)),
            ),
          ),
        ],
        if (status == 'active') ...[
          OutlinedButton.icon(
            onPressed: () => _confirmAction(
              context,
              'Suspend Supplier?',
              'The supplier will lose dashboard access immediately.',
              () => adminVM.suspendSupplier(supplier.uid),
              confirmIcon: Icons.block_rounded,
              isDestructive: true,
            ),
            icon: const Icon(Icons.block_rounded, size: 18),
            label: const Text('Suspend Account'),
            style: AdminTheme.destructiveButtonStyle().copyWith(
              minimumSize: WidgetStateProperty.all(const Size(160, 46)),
            ),
          ),
        ],
        if (status == 'suspended' || status == 'rejected') ...[
          ElevatedButton.icon(
            onPressed: () => _confirmAction(
              context,
              'Activate Supplier?',
              'The supplier will regain full access to the platform.',
              () => adminVM.reactivateSupplier(supplier.uid),
              confirmIcon: Icons.bolt_rounded,
            ),
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: const Text('Activate Account'),
            style: AdminTheme.primaryButtonStyle(height: 46).copyWith(
              minimumSize: WidgetStateProperty.all(const Size(160, 46)),
            ),
          ),
        ],
        OutlinedButton.icon(
          onPressed: () => _confirmAction(
            context,
            'Delete Permanently?',
            'This action is irreversible. All supplier records will be removed.',
            () => adminVM.deleteSupplierPermanently(supplier.uid),
            confirmIcon: Icons.delete_forever_rounded,
            isDestructive: true,
          ),
          icon: const Icon(Icons.delete_forever_rounded, size: 18),
          label: const Text('Delete'),
          style: AdminTheme.destructiveButtonStyle().copyWith(
            minimumSize: WidgetStateProperty.all(const Size(120, 46)),
          ),
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
    IconData? confirmIcon,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            if (confirmIcon != null) Icon(confirmIcon, color: isDestructive ? AdminColors.red : AdminColors.navy),
            if (confirmIcon != null) const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
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
                        behavior: SnackBarBehavior.floating,
                        content: Text('Action completed successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(behavior: SnackBarBehavior.floating, content: Text('Error: $e')),
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
        title: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: AdminColors.red),
            const SizedBox(width: 10),
            const Text('Reject Application'),
          ],
        ),
        content: TextField(
          controller: reasonController,
          decoration: AdminTheme.inputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'Shown to the applicant',
          ),
          maxLines: 3,
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
