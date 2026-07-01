import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../models/user_model.dart';
import '../../models/company_model.dart';
import '../../constants/app_colors.dart';
import '../../utils/pakistan_validators.dart';
import '../../widgets/admin/admin_widgets.dart';

class AdminCeoManagementView extends StatefulWidget {
  const AdminCeoManagementView({super.key});

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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('CEO Management',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCeoStream('pending', adminVM),
          _buildCeoStream('active', adminVM),
          _buildCeoStream('suspended', adminVM),
          _buildCeoStream('rejected', adminVM),
        ],
      ),
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
                  backgroundColor: AppColors.ceoAccent.withValues(alpha: 0.1),
                  child: const Icon(Icons.business_center_outlined,
                      color: AppColors.ceoAccent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ceoName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(ceo.email,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      if (company != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            company.name,
                            style: const TextStyle(
                              color: AppColors.primary,
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
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM d, yyyy').format(ceo.createdAt),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                if (ceo.phone.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  const Icon(Icons.phone_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(ceo.phone,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
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
            _buildActionButtons(company, ceo, adminVM),
          ],
        ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Approve'),
          ),
          OutlinedButton(
            onPressed: () => _showRejectDialog(company?.id, ceo.uid, adminVM),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
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
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amber,
              side: const BorderSide(color: Colors.amber),
            ),
            child: const Text('Suspend'),
          ),
        ],
        if (status == 'suspended' || status == 'rejected') ...[
          OutlinedButton(
            onPressed: () => _showConfirmDialog(
              'Activate Account',
              'Restore dashboard access?',
              () => adminVM.activateCEO(company?.id, ceo.uid),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: const BorderSide(color: Colors.green),
            ),
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
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            border: OutlineInputBorder(),
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
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
