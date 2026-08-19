import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../models/user_model.dart';
import '../../models/company_model.dart';
import '../../theme/admin_theme.dart';
import '../../utils/pakistan_validators.dart';
import '../../widgets/admin/admin_widgets.dart';

class AdminCeoManagementView extends StatefulWidget {
  final bool embedded;

  const AdminCeoManagementView({super.key, this.embedded = false});

  @override
  State<AdminCeoManagementView> createState() => _AdminCeoManagementViewState();
}

class _AdminCeoManagementViewState extends State<AdminCeoManagementView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedCeoUids = {};
  final Map<String, String?> _ceoToCompanyMap = {};
  bool _isBulkProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedCeoUids.clear());
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _bulkApprove(AdminViewModel adminVM) async {
    if (_selectedCeoUids.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Approve CEOs'),
        content: Text('Approve all ${_selectedCeoUids.length} selected CEOs and generate company invite codes?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('APPROVE ALL', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isBulkProcessing = true);
    try {
      for (final uid in _selectedCeoUids) {
        final companyId = _ceoToCompanyMap[uid];
        await adminVM.acceptCEO(companyId, uid);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully approved ${_selectedCeoUids.length} CEOs')),
        );
        setState(() => _selectedCeoUids.clear());
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
        _buildCeoStream('pending', adminVM),
        _buildCeoStream('active', adminVM),
        _buildCeoStream('suspended', adminVM),
        _buildCeoStream('rejected', adminVM),
      ],
    );

    return Scaffold(
      backgroundColor: AdminColors.screenBg,
      appBar: widget.embedded 
          ? null 
          : AdminAppBar(
              title: 'CEO Management',
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
      floatingActionButton: (_tabController.index == 0 && _selectedCeoUids.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: _isBulkProcessing ? null : () => _bulkApprove(adminVM),
              backgroundColor: AdminColors.amber,
              label: _isBulkProcessing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Approve Selected (${_selectedCeoUids.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              icon: const Icon(Icons.done_all, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildCeoStream(String status, AdminViewModel adminVM) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'CEO')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return AdminEmptyState(
            icon: Icons.business_outlined,
            message: 'No $status CEOs found.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final ceo = UserModel.fromMap(data);
            
            // Map for bulk approval lookup
            _ceoToCompanyMap[ceo.uid] = ceo.companyId;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('companies')
                  .doc(ceo.companyId)
                  .get(),
              builder: (context, companySnap) {
                CompanyModel? company;
                if (companySnap.hasData && companySnap.data!.exists) {
                  company = CompanyModel.fromMap(
                    companySnap.data!.data() as Map<String, dynamic>,
                  );
                }
                return _buildCeoCard(ceo, company, adminVM);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCeoCard(
    UserModel ceo,
    CompanyModel? company,
    AdminViewModel adminVM,
  ) {
    final status = (ceo.status ?? 'pending').toLowerCase();
    final isPending = status == 'pending';
    final isSelected = _selectedCeoUids.contains(ceo.uid);

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
                          _selectedCeoUids.add(ceo.uid);
                        } else {
                          _selectedCeoUids.remove(ceo.uid);
                        }
                      });
                    },
                    activeColor: AdminColors.amber,
                  ),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AdminColors.navy.withValues(alpha: 0.1),
                  child: const Icon(Icons.business_center_outlined,
                      color: AdminColors.navy, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(company?.ceoFullName ?? ceo.name,
                          style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AdminColors.navy)),
                      Text(ceo.email,
                          style: AdminTheme.mutedStyle(size: 12)),
                      if (company != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            company.name,
                            style: GoogleFonts.plusJakartaSans(
                              color: AdminColors.navy,
                              fontSize: 12,
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
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: AdminColors.textGrey),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM d, yyyy').format(ceo.createdAt),
                  style: AdminTheme.mutedStyle(size: 12),
                ),
                if (ceo.phone.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.phone_outlined,
                      size: 14, color: AdminColors.textGrey),
                  const SizedBox(width: 4),
                  Text(ceo.phone, style: AdminTheme.mutedStyle(size: 12)),
                ],
              ],
            ),
            if (company != null) ...[
              const Divider(height: 28),
              AdminApprovalSection(
                title: 'COMPANY IDENTITY',
                children: [
                  AdminDetailRow(label: 'Company name', value: company.name),
                  AdminDetailRow(
                      label: 'Company type',
                      value: company.companyType ?? ''),
                  AdminDetailRow(
                    label: 'Years in operation',
                    value: company.yearsInOperation?.toString() ?? '',
                  ),
                  AdminDetailRow(
                    label: 'Registration / NTN',
                    value: company.registrationNumber,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AdminApprovalSection(
                title: 'CEO / AUTHORIZED PERSON',
                children: [
                  AdminDetailRow(label: 'Full name', value: company.ceoFullName ?? ceo.name),
                  AdminDetailRow(label: 'Designation', value: company.designation ?? 'CEO'),
                  AdminDetailRow(label: 'CNIC', value: _formatCnic(company.cnicNumber ?? ceo.cnic)),
                  const SizedBox(height: 4),
                  AdminDocumentThumbnailRow(
                    documents: [
                      (label: 'CNIC Front', url: company.cnicFrontUrl),
                      (label: 'CNIC Back', url: company.cnicBackUrl),
                    ],
                  ),
                ],
              ),
            ],
            const Divider(height: 28),
            _buildActionButtons(company, ceo, adminVM),
          ],
        ),
    );
  }

  String _formatCnic(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    return PakistanValidators.formatCnic(raw);
  }

  Widget _buildActionButtons(
    CompanyModel? company,
    UserModel ceo,
    AdminViewModel adminVM,
  ) {
    final status = (ceo.status ?? 'pending').toLowerCase();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (status == 'pending') ...[
          ElevatedButton(
            onPressed: () => _showConfirmDialog(
              'Approve CEO',
              'Activate account and generate company invite code?',
              () => adminVM.acceptCEO(company?.id, ceo.uid),
            ),
            style: AdminTheme.primaryButtonStyle(height: 46),
            child: const Text('Approve'),
          ),
          OutlinedButton(
            onPressed: () => _showRejectDialog(company?.id, ceo.uid, adminVM),
            style: AdminTheme.destructiveButtonStyle(),
            child: const Text('Reject'),
          ),
        ],
        if (status == 'active') ...[
          OutlinedButton(
            onPressed: () => _showConfirmDialog(
              'Suspend Account',
              'User will lose access immediately.',
              () => adminVM.suspendCEO(company?.id, ceo.uid),
            ),
            style: AdminTheme.destructiveButtonStyle(),
            child: const Text('Suspend'),
          ),
        ],
        if (status == 'suspended' || status == 'rejected') ...[
          ElevatedButton(
            onPressed: () => _showConfirmDialog(
              'Activate Account',
              'Restore dashboard access?',
              () => adminVM.activateCEO(company?.id, ceo.uid),
            ),
            style: AdminTheme.primaryButtonStyle(height: 46),
            child: const Text('Activate'),
          ),
        ],
      ],
    );
  }

  void _showConfirmDialog(
    String title,
    String message,
    Future<void> Function() action,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await action();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Confirm',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(
    String? companyId,
    String ceoUid,
    AdminViewModel adminVM,
  ) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Application'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: AdminTheme.inputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'Shown to the applicant',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              adminVM.rejectCEO(companyId, ceoUid, reason);
              Navigator.pop(context);
            },
            child: Text(
              'Reject',
              style: GoogleFonts.plusJakartaSans(color: AdminColors.red),
            ),
          ),
        ],
      ),
    );
  }
}
