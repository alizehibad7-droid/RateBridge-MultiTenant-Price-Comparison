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

  const AdminCeoManagementView({
    super.key,
    this.embedded = false,
    @visibleForTesting this.debugFirestore,
  });

  final FirebaseFirestore? debugFirestore;

  @override
  State<AdminCeoManagementView> createState() => _AdminCeoManagementViewState();
}

class _AdminCeoManagementViewState extends State<AdminCeoManagementView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedCeoUids = {};
  final Map<String, String?> _ceoToCompanyMap = {};
  bool _isBulkProcessing = false;

  FirebaseFirestore get _db =>
      widget.debugFirestore ?? FirebaseFirestore.instance;

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
        title: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: AdminColors.navy),
            const SizedBox(width: 10),
            const Text('Bulk Approval'),
          ],
        ),
        content: Text('Approve all ${_selectedCeoUids.length} selected CEOs and generate company invite codes?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('APPROVE ALL'),
            style: AdminTheme.primaryButtonStyle(height: 40),
          ),
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
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Successfully approved ${_selectedCeoUids.length} CEOs'),
              ],
            ),
          ),
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
      floatingActionButton: (_tabController.index == 0 && _selectedCeoUids.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: _isBulkProcessing ? null : () => _bulkApprove(adminVM),
              backgroundColor: AdminColors.navy,
              label: _isBulkProcessing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Approve Selected (${_selectedCeoUids.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              icon: const Icon(Icons.verified_user_rounded, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildCeoStream(String status, AdminViewModel adminVM) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
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
            icon: _emptyIcon(status),
            message: 'No $status CEOs found.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final ceo = UserModel.fromMap(data);
            
            _ceoToCompanyMap[ceo.uid] = ceo.companyId;

            return FutureBuilder<DocumentSnapshot>(
              future: _db
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

  IconData _emptyIcon(String status) {
    switch(status) {
      case 'pending': return Icons.person_search_rounded;
      case 'active': return Icons.verified_user_rounded;
      case 'suspended': return Icons.person_off_rounded;
      default: return Icons.no_accounts_rounded;
    }
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
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 24, height: 24,
                      child: Checkbox(
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: AdminColors.navy.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.business_center_rounded,
                      color: AdminColors.navy, size: 24),
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
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 12, color: AdminColors.textGrey),
                          const SizedBox(width: 4),
                          Text(ceo.email, style: AdminTheme.mutedStyle(size: 12)),
                        ],
                      ),
                      if (company != null)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AdminColors.navy.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            company.name,
                            style: GoogleFonts.plusJakartaSans(
                              color: AdminColors.navy,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
                const Icon(Icons.calendar_today_rounded, size: 14, color: AdminColors.textGrey),
                const SizedBox(width: 6),
                Text(
                  'Joined ${DateFormat('MMM d, yyyy').format(ceo.createdAt)}',
                  style: AdminTheme.mutedStyle(size: 12),
                ),
                if (ceo.phone.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.phone_outlined, size: 14, color: AdminColors.textGrey),
                  const SizedBox(width: 6),
                  Text(ceo.phone, style: AdminTheme.mutedStyle(size: 12)),
                ],
              ],
            ),
            if (company != null) ...[
              const Divider(height: 32),
              AdminApprovalSection(
                title: 'COMPANY IDENTITY',
                children: [
                  AdminDetailRow(label: 'Company Name', value: company.name),
                  AdminDetailRow(label: 'Business Type', value: company.companyType ?? 'N/A'),
                  AdminDetailRow(label: 'Experience', value: '${company.yearsInOperation ?? 0} years'),
                  AdminDetailRow(label: 'Registration / NTN', value: company.registrationNumber),
                ],
              ),
              const SizedBox(height: 20),
              AdminApprovalSection(
                title: 'CEO / AUTHORIZED PERSON',
                children: [
                  AdminDetailRow(label: 'Full Name', value: company.ceoFullName ?? ceo.name),
                  AdminDetailRow(label: 'Designation', value: company.designation ?? 'CEO'),
                  AdminDetailRow(label: 'CNIC Number', value: _formatCnic(company.cnicNumber ?? ceo.cnic)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.attachment_rounded, size: 14, color: AdminColors.textGrey),
                      const SizedBox(width: 6),
                      Text('VERIFICATION DOCUMENTS', style: AdminTheme.sectionHeaderStyle().copyWith(fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AdminDocumentThumbnailRow(
                    documents: [
                      (label: 'CNIC Front', url: company.cnicFrontUrl),
                      (label: 'CNIC Back', url: company.cnicBackUrl),
                    ],
                  ),
                ],
              ),
            ],
            const Divider(height: 32),
            _buildActionButtons(company, ceo, adminVM),
          ],
        ),
    );
  }

  String _formatCnic(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Not Provided';
    return PakistanValidators.formatCnic(raw);
  }

  Widget _buildActionButtons(
    CompanyModel? company,
    UserModel ceo,
    AdminViewModel adminVM,
  ) {
    final status = (ceo.status ?? 'pending').toLowerCase();

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        if (status == 'pending') ...[
          ElevatedButton.icon(
            onPressed: () => _showConfirmDialog(
              'Approve CEO Account',
              'This will activate the account and generate a unique company invite code.',
              () => adminVM.acceptCEO(company?.id, ceo.uid),
              confirmIcon: Icons.verified_user_rounded,
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Approve'),
            style: AdminTheme.primaryButtonStyle(height: 46).copyWith(
              minimumSize: WidgetStateProperty.all(const Size(140, 46)),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _showRejectDialog(company?.id, ceo.uid, adminVM),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Reject'),
            style: AdminTheme.destructiveButtonStyle().copyWith(
              minimumSize: WidgetStateProperty.all(const Size(120, 46)),
            ),
          ),
        ],
        if (status == 'active') ...[
          OutlinedButton.icon(
            onPressed: () => _showConfirmDialog(
              'Suspend Account',
              'The user will lose dashboard access immediately. Active field users will also be restricted.',
              () => adminVM.suspendCEO(company?.id, ceo.uid),
              confirmIcon: Icons.block_rounded,
              isDestructive: true,
            ),
            icon: const Icon(Icons.block_rounded, size: 18),
            label: const Text('Suspend Access'),
            style: AdminTheme.destructiveButtonStyle().copyWith(
              minimumSize: WidgetStateProperty.all(const Size(170, 46)),
            ),
          ),
        ],
        if (status == 'suspended' || status == 'rejected') ...[
          ElevatedButton.icon(
            onPressed: () => _showConfirmDialog(
              'Reactivate Account',
              'Restore full dashboard access for this CEO?',
              () => adminVM.activateCEO(company?.id, ceo.uid),
              confirmIcon: Icons.bolt_rounded,
            ),
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: const Text('Reactivate CEO'),
            style: AdminTheme.primaryButtonStyle(height: 46).copyWith(
              minimumSize: WidgetStateProperty.all(const Size(170, 46)),
            ),
          ),
        ],
      ],
    );
  }

  void _showConfirmDialog(
    String title,
    String message,
    Future<void> Function() action, {
    IconData? confirmIcon,
    bool isDestructive = false,
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
                await action();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      behavior: SnackBarBehavior.floating,
                      content: Text('Operation completed successfully')),
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
    String? companyId,
    String ceoUid,
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
          maxLines: 3,
          decoration: AdminTheme.inputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'Provide context for the applicant...',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              adminVM.rejectCEO(companyId, ceoUid, reason);
              Navigator.pop(context);
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
