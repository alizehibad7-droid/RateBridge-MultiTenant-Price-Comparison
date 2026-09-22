import 'package:flutter/foundation.dart';
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
            const Text('Corporate Approval'),
          ],
        ),
        content: Text('Approve all ${_selectedCeoUids.length} selected CEO applications and activate their firms?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: AdminTheme.primaryButtonStyle(),
            child: const Text('APPROVE SELECTED'),
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
          const SnackBar(content: Text('Bulk approval sequence completed.')),
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
                _buildCeoContent('pending', adminVM),
                _buildCeoContent('active', adminVM),
                _buildCeoContent('suspended', adminVM),
                _buildCeoContent('rejected', adminVM),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final double screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.fromLTRB(screenWidth < 600 ? 12 : 24, 24, screenWidth < 600 ? 12 : 24, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Corporate Management', style: AdminTheme.titleStyle(size: screenWidth < 600 ? 20 : 24)),
                const SizedBox(height: 4),
                Text('Review and manage CEO applications and company identities.', style: AdminTheme.mutedStyle(size: screenWidth < 600 ? 12 : 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final double screenWidth = MediaQuery.of(context).size.width;
    return Container(
      margin: EdgeInsets.fromLTRB(screenWidth < 600 ? 12 : 24, 20, screenWidth < 600 ? 12 : 24, 0),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminColors.border)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: AdminColors.navy,
        indicatorWeight: 3,
        labelColor: AdminColors.navy,
        unselectedLabelColor: AdminColors.textGrey,
        labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: [
          _buildTab('Pending Approval', Icons.hourglass_empty_rounded),
          _buildTab('Active Firms', Icons.verified_user_rounded),
          _buildTab('Suspended', Icons.block_rounded),
          _buildTab('Rejected', Icons.cancel_outlined),
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

  Widget _buildCeoContent(String status, AdminViewModel adminVM) {
    final double screenWidth = MediaQuery.of(context).size.width;
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
            message: 'No CEOs found in this category.',
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(screenWidth < 600 ? 12 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (status == 'pending' && _selectedCeoUids.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Text('${_selectedCeoUids.length} selected', style: AdminTheme.bodyStyle(weight: FontWeight.w700)),
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
              screenWidth >= 900
                  ? AdminCard(
                      padding: EdgeInsets.zero,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildCeoTable(docs, adminVM, status),
                      ),
                    )
                  : _buildCeoMobileList(docs, adminVM, status),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCeoTable(List<QueryDocumentSnapshot> docs, AdminViewModel adminVM, String status) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: const Color(0xFFF1F5F9)),
      child: DataTable(
        headingRowHeight: 48,
        dataRowMaxHeight: 64,
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
        horizontalMargin: 20,
        columnSpacing: 24,
        columns: [
          DataColumn(label: Text('CEO / IDENTITY', style: AdminTheme.sectionHeaderStyle())),
          DataColumn(label: Text('ORGANIZATION', style: AdminTheme.sectionHeaderStyle())),
          DataColumn(label: Text('SUBMITTED', style: AdminTheme.sectionHeaderStyle())),
          DataColumn(label: Text('STATUS', style: AdminTheme.sectionHeaderStyle())),
          DataColumn(label: Text('MANAGEMENT', style: AdminTheme.sectionHeaderStyle())),
        ],
        rows: docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final ceo = UserModel.fromMap(data);
          _ceoToCompanyMap[ceo.uid] = ceo.companyId;

          return DataRow(
            cells: [
              DataCell(
                Row(
                  children: [
                    if (status == 'pending')
                      SizedBox(
                        width: 32,
                        child: Checkbox(
                          value: _selectedCeoUids.contains(ceo.uid),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) _selectedCeoUids.add(ceo.uid);
                              else _selectedCeoUids.remove(ceo.uid);
                            });
                          },
                        ),
                      ),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AdminColors.navy.withValues(alpha: 0.1),
                      child: Text(ceo.name[0].toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminColors.navy)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ceo.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AdminColors.navy, fontSize: 13)),
                        Text(ceo.email, style: AdminTheme.mutedStyle(size: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              DataCell(
                FutureBuilder<DocumentSnapshot>(
                  future: _db.collection('companies').doc(ceo.companyId).get(),
                  builder: (context, snap) {
                    final cName = (snap.data?.data() as Map<String, dynamic>?)?['name'] ?? 'Loading...';
                    return Text(cName, style: AdminTheme.bodyStyle(weight: FontWeight.w600));
                  },
                ),
              ),
              DataCell(Text(DateFormat('MMM d, yyyy').format(ceo.createdAt), style: AdminTheme.bodyStyle())),
              DataCell(StatusChip(status: ceo.status ?? 'pending')),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18, color: AdminColors.navy),
                      onPressed: () => _showCeoDetails(ceo),
                      tooltip: 'View Documents',
                    ),
                    if (status == 'pending') ...[
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: AdminColors.green, size: 18),
                        onPressed: () => adminVM.acceptCEO(ceo.companyId, ceo.uid),
                        tooltip: 'Approve',
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined, color: AdminColors.red, size: 18),
                        onPressed: () => _showRejectDialog(ceo.companyId, ceo.uid, adminVM),
                        tooltip: 'Reject',
                      ),
                    ],
                    if (status == 'active')
                      IconButton(
                        icon: const Icon(Icons.block_rounded, color: AdminColors.red, size: 18),
                        onPressed: () => adminVM.suspendCEO(ceo.companyId, ceo.uid),
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

  Widget _buildCeoMobileList(List<QueryDocumentSnapshot> docs, AdminViewModel adminVM, String status) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        final ceo = UserModel.fromMap(data);
        _ceoToCompanyMap[ceo.uid] = ceo.companyId;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AdminColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (status == 'pending')
                      Checkbox(
                        value: _selectedCeoUids.contains(ceo.uid),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) _selectedCeoUids.add(ceo.uid);
                            else _selectedCeoUids.remove(ceo.uid);
                          });
                        },
                      ),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AdminColors.navy.withValues(alpha: 0.1),
                      child: Text(ceo.name[0].toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminColors.navy)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ceo.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AdminColors.navy, fontSize: 14)),
                          Text(ceo.email, style: AdminTheme.mutedStyle(size: 12)),
                        ],
                      ),
                    ),
                    StatusChip(status: ceo.status ?? 'pending'),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Organization:', style: AdminTheme.mutedStyle(size: 12)),
                    FutureBuilder<DocumentSnapshot>(
                      future: _db.collection('companies').doc(ceo.companyId).get(),
                      builder: (context, snap) {
                        final cName = (snap.data?.data() as Map<String, dynamic>?)?['name'] ?? 'Loading...';
                        return Text(cName, style: AdminTheme.bodyStyle(weight: FontWeight.w600, size: 13));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Submitted:', style: AdminTheme.mutedStyle(size: 12)),
                    Text(DateFormat('MMM d, yyyy').format(ceo.createdAt), style: AdminTheme.bodyStyle(size: 13)),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 20, color: AdminColors.navy),
                      onPressed: () => _showCeoDetails(ceo),
                      tooltip: 'View Documents',
                    ),
                    if (status == 'pending') ...[
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: AdminColors.green, size: 20),
                        onPressed: () => adminVM.acceptCEO(ceo.companyId, ceo.uid),
                        tooltip: 'Approve',
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined, color: AdminColors.red, size: 20),
                        onPressed: () => _showRejectDialog(ceo.companyId, ceo.uid, adminVM),
                        tooltip: 'Reject',
                      ),
                    ],
                    if (status == 'active')
                      IconButton(
                        icon: const Icon(Icons.block_rounded, color: AdminColors.red, size: 20),
                        onPressed: () => adminVM.suspendCEO(ceo.companyId, ceo.uid),
                        tooltip: 'Suspend',
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCeoDetails(UserModel ceo) {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<DocumentSnapshot>(
        future: _db.collection('companies').doc(ceo.companyId).get(),
        builder: (context, companySnap) {
          CompanyModel? company;
          if (companySnap.hasData && companySnap.data!.exists) {
            company = CompanyModel.fromMap(
              companySnap.data!.data() as Map<String, dynamic>,
            );
          }
          final double screenWidth = MediaQuery.of(context).size.width;

          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              width: screenWidth > 850 ? 800 : screenWidth - 32,
              padding: EdgeInsets.all(screenWidth < 600 ? 16 : 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Corporate Identity Review', style: AdminTheme.titleStyle(size: screenWidth < 600 ? 18 : 22)),
                              const SizedBox(height: 4),
                              Text('Verifying entity ownership and legal credentials.', style: AdminTheme.mutedStyle(size: screenWidth < 600 ? 11 : 13)),
                            ],
                          ),
                        ),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    if (company != null) ...[
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth > 650) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: AdminApprovalSection(
                                    title: 'Business Credentials',
                                    children: [
                                      AdminDetailRow(label: 'Legal Name', value: company!.name),
                                      AdminDetailRow(label: 'Industry Sector', value: company.companyType ?? 'Construction'),
                                      AdminDetailRow(label: 'NTN / Reg Number', value: company.registrationNumber),
                                      AdminDetailRow(label: 'Market Tenure', value: '${company.yearsInOperation ?? 0} Years'),
                                      AdminDetailRow(label: 'Corporate City', value: company.city),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 1,
                                  child: AdminApprovalSection(
                                    title: 'Executive Representative',
                                    children: [
                                      AdminDetailRow(label: 'Full Name', value: company.ceoFullName ?? ceo.name),
                                      AdminDetailRow(label: 'Designation', value: company.designation ?? 'CEO'),
                                      AdminDetailRow(label: 'Identity Number', value: PakistanValidators.formatCnic(company.cnicNumber ?? ceo.cnic ?? '')),
                                      AdminDetailRow(label: 'Contact Primary', value: ceo.phone),
                                      AdminDetailRow(label: 'Email Identity', value: ceo.email),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AdminApprovalSection(
                                  title: 'Business Credentials',
                                  children: [
                                    AdminDetailRow(label: 'Legal Name', value: company!.name),
                                    AdminDetailRow(label: 'Industry Sector', value: company.companyType ?? 'Construction'),
                                    AdminDetailRow(label: 'NTN / Reg Number', value: company.registrationNumber),
                                    AdminDetailRow(label: 'Market Tenure', value: '${company.yearsInOperation ?? 0} Years'),
                                    AdminDetailRow(label: 'Corporate City', value: company.city),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                AdminApprovalSection(
                                  title: 'Executive Representative',
                                  children: [
                                    AdminDetailRow(label: 'Full Name', value: company.ceoFullName ?? ceo.name),
                                    AdminDetailRow(label: 'Designation', value: company.designation ?? 'CEO'),
                                    AdminDetailRow(label: 'Identity Number', value: PakistanValidators.formatCnic(company.cnicNumber ?? ceo.cnic ?? '')),
                                    AdminDetailRow(label: 'Contact Primary', value: ceo.phone),
                                    AdminDetailRow(label: 'Email Identity', value: ceo.email),
                                  ],
                                ),
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      AdminApprovalSection(
                        title: 'Verification Documents',
                        children: [
                          const SizedBox(height: 8),
                          AdminDocumentThumbnailRow(
                            documents: [
                              (label: 'CNIC FRONT', url: company.cnicFrontUrl),
                              (label: 'CNIC BACK', url: company.cnicBackUrl),
                              if (company.registrationCertUrl != null) 
                                (label: 'CORP CERTIFICATE', url: company.registrationCertUrl),
                            ],
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('CLOSE'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ApprovalActions(
                            onApprove: () {
                              Provider.of<AdminViewModel>(context, listen: false).acceptCEO(company?.id, ceo.uid);
                              Navigator.pop(context);
                            },
                            onReject: (reason) {
                              Provider.of<AdminViewModel>(context, listen: false).rejectCEO(company?.id, ceo.uid, reason);
                              Navigator.pop(context);
                            },
                          ),
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
      case 'active': return Icons.verified_user_outlined;
      case 'suspended': return Icons.person_off_outlined;
      default: return Icons.no_accounts_outlined;
    }
  }

  void _showRejectDialog(String? companyId, String ceoUid, AdminViewModel adminVM) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deny CEO Application'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: AdminTheme.inputDecoration(
            labelText: 'Decline Reason',
            hintText: 'Provide context for the CEO...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              adminVM.rejectCEO(companyId, ceoUid, reason);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.red),
            child: const Text('REJECT'),
          ),
        ],
      ),
    );
  }
}
