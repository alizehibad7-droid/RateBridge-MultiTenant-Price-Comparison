import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/supplier_model.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../theme/admin_theme.dart';
import '../../widgets/admin/admin_widgets.dart';
import '../../widgets/supplier_performance_scorecard.dart';

class AdminSupplierManagementView extends StatefulWidget {
  final bool embedded;

  const AdminSupplierManagementView({
    super.key,
    this.embedded = false,
    @visibleForTesting this.debugFirestore,
  });

  final FirebaseFirestore? debugFirestore;

  @override
  State<AdminSupplierManagementView> createState() =>
      _AdminSupplierManagementViewState();
}

class _AdminSupplierManagementViewState extends State<AdminSupplierManagementView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedSupplierUids = {};
  bool _isBulkProcessing = false;

  FirebaseFirestore get _db =>
      widget.debugFirestore ?? FirebaseFirestore.instance;

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
        title: const Text('Mass Approval'),
        content: Text('Activate all ${_selectedSupplierUids.length} selected supplier accounts and grant marketplace visibility?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: AdminTheme.primaryButtonStyle(),
            child: const Text('PROCEED WITH APPROVAL'),
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
          const SnackBar(content: Text('Bulk supplier activation completed.')),
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

    return Container(
      color: AdminColors.screenBg,
      child: Column(
        children: [
          if (!widget.embedded) _buildHeader(),
          _buildTabs(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSupplierContent('pending', adminVM),
                _buildSupplierContent('active', adminVM),
                _buildSupplierContent('suspended', adminVM),
                _buildSupplierContent('rejected', adminVM),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Supply Chain Partners', style: AdminTheme.titleStyle(size: 24)),
              const SizedBox(height: 4),
              Text('Oversee material suppliers, product inventories, and service levels.', style: AdminTheme.mutedStyle()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: AdminColors.primary,
        indicatorWeight: 3,
        labelColor: AdminColors.primary,
        unselectedLabelColor: AdminColors.textGrey,
        labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: [
          _buildTab('Awaiting Approval', Icons.pending_outlined),
          _buildTab('Active Partners', Icons.storefront_outlined),
          _buildTab('Suspended', Icons.block_outlined),
          _buildTab('Rejected', Icons.domain_disabled_outlined),
        ],
      ),
    );
  }

  Tab _buildTab(String label, IconData icon) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildSupplierContent(String status, AdminViewModel adminVM) {
    return StreamBuilder<List<UserModel>>(
      stream: _db
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
            message: 'No suppliers found in this segment.',
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (status == 'pending' && _selectedSupplierUids.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Text('${_selectedSupplierUids.length} applications selected', style: AdminTheme.bodyStyle(weight: FontWeight.w700)),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _isBulkProcessing ? null : () => _bulkApprove(adminVM),
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: const Text('Bulk Approve'),
                        style: AdminTheme.primaryButtonStyle().copyWith(
                          backgroundColor: WidgetStateProperty.all(AdminColors.green),
                        ),
                      ),
                    ],
                  ),
                ),
              AdminCard(
                padding: EdgeInsets.zero,
                child: _buildSupplierTable(suppliers, adminVM, status),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSupplierTable(List<UserModel> suppliers, AdminViewModel adminVM, String status) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: const Color(0xFFF1F5F9)),
      child: DataTable(
        headingRowHeight: 48,
        dataRowMaxHeight: 64,
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
        horizontalMargin: 20,
        columnSpacing: 24,
        columns: [
          DataColumn(label: Text('BUSINESS ENTITY', style: AdminTheme.sectionHeaderStyle())),
          DataColumn(label: Text('LOCATION', style: AdminTheme.sectionHeaderStyle())),
          DataColumn(label: Text('TRUST SCORE', style: AdminTheme.sectionHeaderStyle())),
          DataColumn(label: Text('STATUS', style: AdminTheme.sectionHeaderStyle())),
          DataColumn(label: Text('OPERATIONS', style: AdminTheme.sectionHeaderStyle())),
        ],
        rows: suppliers.map((supplier) {
          return DataRow(
            cells: [
              DataCell(
                Row(
                  children: [
                    if (status == 'pending')
                      SizedBox(
                        width: 32,
                        child: Checkbox(
                          value: _selectedSupplierUids.contains(supplier.uid),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) _selectedSupplierUids.add(supplier.uid);
                              else _selectedSupplierUids.remove(supplier.uid);
                            });
                          },
                        ),
                      ),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AdminColors.amber.withValues(alpha: 0.1),
                      child: Text(supplier.name[0].toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminColors.darkAmber)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(supplier.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AdminColors.navy, fontSize: 13)),
                        Text(supplier.email, style: AdminTheme.mutedStyle(size: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              DataCell(Text(supplier.city, style: AdminTheme.bodyStyle())),
              DataCell(
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: AdminColors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text((supplier.rating ?? 0.0).toStringAsFixed(1), style: AdminTheme.bodyStyle(weight: FontWeight.w700)),
                  ],
                ),
              ),
              DataCell(StatusChip(status: supplier.status ?? 'pending')),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18, color: AdminColors.primary),
                      onPressed: () => _showSupplierDetails(supplier),
                      tooltip: 'View Profile',
                    ),
                    if (status == 'pending') ...[
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: AdminColors.green, size: 18),
                        onPressed: () => adminVM.approveSupplier(supplier.uid),
                        tooltip: 'Approve',
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined, color: AdminColors.red, size: 18),
                        onPressed: () => _showRejectDialog(supplier.uid, adminVM),
                        tooltip: 'Reject',
                      ),
                    ],
                    if (status == 'active')
                      IconButton(
                        icon: const Icon(Icons.block_rounded, color: AdminColors.red, size: 18),
                        onPressed: () => adminVM.suspendSupplier(supplier.uid),
                        tooltip: 'Suspend',
                      ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  void _showSupplierDetails(UserModel supplier) {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<DocumentSnapshot>(
        future: _db.collection('suppliers').doc(supplier.uid).get(),
        builder: (context, profileSnap) {
          SupplierModel? profile;
          if (profileSnap.hasData && profileSnap.data!.exists) {
            profile = SupplierModel.fromMap(profileSnap.data!.data() as Map<String, dynamic>);
          }
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              width: 800,
              padding: const EdgeInsets.all(32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Supplier Entity Verification', style: AdminTheme.titleStyle(size: 22)),
                            const SizedBox(height: 4),
                            Text('Evaluating marketplace compatibility and business status.', style: AdminTheme.mutedStyle()),
                          ],
                        ),
                        const Spacer(),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              AdminApprovalSection(
                                title: 'Trade Information',
                                children: [
                                  AdminDetailRow(label: 'Trading Name', value: profile?.name ?? supplier.name),
                                  AdminDetailRow(label: 'Legal Entity', value: profile?.businessType ?? 'Individual'),
                                  AdminDetailRow(label: 'Industry Experience', value: '${profile?.yearsInBusiness ?? 0} Years'),
                                  AdminDetailRow(label: 'Tax / NTN', value: profile?.businessRegistrationNumber ?? 'N/A'),
                                ],
                              ),
                              const SizedBox(height: 20),
                              AdminApprovalSection(
                                title: 'Product Catalog',
                                children: [
                                  AdminChipList(items: profile?.declaredCategories ?? const []),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              AdminApprovalSection(
                                title: 'Performance Metrics',
                                children: [
                                  SupplierPerformanceScorecard(
                                    supplierId: supplier.uid,
                                    averageRating: supplier.rating ?? 0.0,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              AdminApprovalSection(
                                title: 'Identity Documents',
                                children: [
                                  const SizedBox(height: 8),
                                  AdminDocumentThumbnailRow(
                                    documents: [
                                      (label: 'IDENTITY FRONT', url: profile?.cnicFrontUrl),
                                      (label: 'IDENTITY BACK', url: profile?.cnicBackUrl),
                                      if (profile?.shopPhotoUrl != null) (label: 'SHOP PHOTO', url: profile?.shopPhotoUrl),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('CLOSE'),
                        ),
                        const SizedBox(width: 12),
                        ApprovalActions(
                          onApprove: () {
                            Provider.of<AdminViewModel>(context, listen: false).approveSupplier(supplier.uid);
                            Navigator.pop(context);
                          },
                          onReject: (reason) {
                            Provider.of<AdminViewModel>(context, listen: false).rejectSupplier(supplier.uid, reason);
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _emptyIcon(String status) {
    switch(status) {
      case 'pending': return Icons.assignment_ind_outlined;
      case 'active': return Icons.store_outlined;
      case 'suspended': return Icons.block_outlined;
      default: return Icons.no_accounts_outlined;
    }
  }

  void _showRejectDialog(String uid, AdminViewModel adminVM) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Supplier Access'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: AdminTheme.inputDecoration(
            labelText: 'Reason for Denial',
            hintText: 'This will be communicated to the partner...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              adminVM.rejectSupplier(uid, reason);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.red),
            child: const Text('REJECT PARTNER'),
          ),
        ],
      ),
    );
  }
}
