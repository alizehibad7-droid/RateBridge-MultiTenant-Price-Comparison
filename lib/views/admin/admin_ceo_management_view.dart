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

    final content = TabBarView(
      controller: _tabController,
      children: [
        _buildCeoStream('pending', adminVM),
        _buildCeoStream('active', adminVM),
        _buildCeoStream('suspended', adminVM),
        _buildCeoStream('rejected', adminVM),
      ],
    );

    if (widget.embedded) {
      return Column(
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
      );
    }

    return Scaffold(
      backgroundColor: AdminColors.screenBg,
      appBar: AdminAppBar(
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
      body: content,
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
            final ceo =
                UserModel.fromMap(docs[index].data() as Map<String, dynamic>);
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
    final ceoName = company?.ceoFullName ?? ceo.name;
    final designation = company?.designation ?? 'CEO';
    final cnic = _formatCnic(company?.cnicNumber ?? ceo.cnic);
    final rejectionReason =
        ceo.rejectionReason ?? company?.rejectionReason ?? '';

    return AdminCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AdminColors.navy.withValues(alpha: 0.1),
                  child: const Icon(Icons.business_center_outlined,
                      color: AdminColors.navy),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ceoName,
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
                  AdminDetailRow(label: 'Full name', value: ceoName),
                  AdminDetailRow(label: 'Designation', value: designation),
                  AdminDetailRow(label: 'CNIC', value: cnic),
                  const SizedBox(height: 4),
                  AdminDocumentThumbnailRow(
                    documents: [
                      (label: 'CNIC Front', url: company.cnicFrontUrl),
                      (label: 'CNIC Back', url: company.cnicBackUrl),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AdminApprovalSection(
                title: 'LOCATION & SCALE',
                children: [
                  AdminDetailRow(
                      label: 'City', value: company.city.isNotEmpty ? company.city : ceo.city),
                  AdminDetailRow(
                    label: 'Address',
                    value: company.address.isNotEmpty
                        ? company.address
                        : (ceo.address ?? ''),
                    maxLines: 5,
                  ),
                  AdminDetailRow(
                    label: 'Monthly procurement',
                    value: company.estimatedMonthlyVolume ?? '',
                  ),
                  AdminDetailRow(
                    label: 'Active sites',
                    value: company.activeSitesCount?.toString() ?? '',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AdminApprovalSection(
                title: 'COMPANY PROOF',
                children: [
                  AdminDocumentThumbnailRow(
                    documents: [
                      (
                        label: 'Registration cert / letterhead',
                        url: company.registrationCertUrl,
                      ),
                      (label: 'Office / site photo', url: company.officePhotoUrl),
                    ],
                  ),
                ],
              ),
            ],
            if (status == 'rejected' && rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminColors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AdminColors.red.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rejection reason',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.red,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rejectionReason,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AdminColors.navy,
                      ),
                    ),
                  ],
                ),
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
