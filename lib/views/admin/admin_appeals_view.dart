import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../theme/admin_theme.dart';
import '../../widgets/admin/admin_widgets.dart';

class AdminAppealsView extends StatefulWidget {
  const AdminAppealsView({super.key});

  @override
  State<AdminAppealsView> createState() => _AdminAppealsViewState();
}

class _AdminAppealsViewState extends State<AdminAppealsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _checkIsDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 900;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = _checkIsDesktop(context);
    return Scaffold(
      backgroundColor: AdminColors.screenBg,
      appBar: isDesktop 
          ? null 
          : AppBar(
              title: Text('Account Appeals', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18, color: AdminColors.navy)),
              backgroundColor: Colors.white,
              elevation: 0,
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: AdminColors.amber,
                labelColor: AdminColors.navy,
                unselectedLabelColor: AdminColors.textGrey,
                tabs: const [
                  Tab(text: 'Pending'),
                  Tab(text: 'Accepted'),
                  Tab(text: 'Rejected'),
                ],
              ),
            ),
      body: Column(
        children: [
          if (isDesktop)
            Material(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: AdminColors.navy,
                unselectedLabelColor: AdminColors.textGrey,
                indicatorColor: AdminColors.amber,
                indicatorWeight: 3,
                labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: const [
                  Tab(text: 'Pending Appeals'),
                  Tab(text: 'Accepted History'),
                  Tab(text: 'Rejected History'),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAppealContent('pending'),
                _buildAppealContent('accepted'),
                _buildAppealContent('rejected'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppealContent(String status) {
    final bool isDesktop = _checkIsDesktop(context);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('appeals')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Firestore Error: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        
        final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
        sortedDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp?;
          final bTime = bData['createdAt'] as Timestamp?;
          
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        if (sortedDocs.isEmpty) {
          return AdminEmptyState(
            icon: Icons.history_edu_rounded,
            message: 'No $status appeals found.',
          );
        }

        if (isDesktop) {
          return _buildAppealTable(sortedDocs, status);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _AppealCard(appeal: data, appealId: doc.id);
          },
        );
      },
    );
  }

  Widget _buildAppealTable(List<QueryDocumentSnapshot> docs, String status) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AdminCard(
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AdminColors.navy.withValues(alpha: 0.03)),
            columns: [
              DataColumn(label: Text('User / Role', style: AdminTheme.sectionHeaderStyle())),
              DataColumn(label: Text('Submitted', style: AdminTheme.sectionHeaderStyle())),
              DataColumn(label: Text('Message Preview', style: AdminTheme.sectionHeaderStyle())),
              DataColumn(label: Text('Status', style: AdminTheme.sectionHeaderStyle())),
              DataColumn(label: Text('Actions', style: AdminTheme.sectionHeaderStyle())),
            ],
            rows: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Unknown';
              final role = data['role'] ?? 'User';
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final message = data['message'] ?? '';

              return DataRow(
                cells: [
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AdminColors.navy)),
                        Text(role.toString().toUpperCase(), style: AdminTheme.mutedStyle(size: 10).copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                DataCell(Text(createdAt != null ? DateFormat('MMM d, yyyy').format(createdAt) : '—', style: AdminTheme.bodyStyle())),
                DataCell(
                  SizedBox(
                    width: 300,
                    child: Text(
                      message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminTheme.bodyStyle(),
                    ),
                  ),
                ),
                DataCell(StatusChip(status: data['status'] ?? 'pending')),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 20),
                        onPressed: () => _showAppealDetailsDialog(data, doc.id),
                        tooltip: 'Review Appeal',
                      ),
                      if (status == 'pending') ...[
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline, color: AdminColors.green, size: 20),
                          onPressed: () => _showConfirmAccept(data, doc.id),
                          tooltip: 'Accept Appeal',
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel_outlined, color: AdminColors.red, size: 20),
                          onPressed: () => _showRejectDialog(context, doc.id, data),
                          tooltip: 'Reject Appeal',
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    ),
  );
}

  void _showAppealDetailsDialog(Map<String, dynamic> appeal, String appealId) {
    final double screenWidth = MediaQuery.of(context).size.width;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: screenWidth > 650 ? 600 : screenWidth - 32,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Appeal Details', style: AdminTheme.titleStyle(size: 20)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const Divider(height: 32),
                _AppealCard(appeal: appeal, appealId: appealId),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showConfirmAccept(Map<String, dynamic> appeal, String appealId) {
    final adminVM = Provider.of<AdminViewModel>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Appeal?'),
        content: const Text('This will restore the account status to active and notify the user.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await adminVM.acceptAppeal(appeal, appealId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.green),
            child: const Text('CONFIRM ACCEPT'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, String appealId, Map<String, dynamic> appeal) {
    final adminVM = Provider.of<AdminViewModel>(context, listen: false);
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Appeal'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason for rejection'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context);
              await adminVM.rejectAppeal(appeal, appealId, controller.text.trim());
            },
            child: const Text('REJECT APPEAL', style: TextStyle(fontWeight: FontWeight.bold, color: AdminColors.red)),
          ),
        ],
      ),
    );
  }
}

class _AppealCard extends StatelessWidget {
  final Map<String, dynamic> appeal;
  final String appealId;

  const _AppealCard({required this.appeal, required this.appealId});

  @override
  Widget build(BuildContext context) {
    final adminVM = Provider.of<AdminViewModel>(context, listen: false);
    final status = appeal['status'] ?? 'pending';
    final role = appeal['role'] ?? 'User';
    final name = appeal['name'] ?? 'Unknown';
    final createdAt = (appeal['createdAt'] as Timestamp?)?.toDate();

    return AdminCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: role.toString().toUpperCase() == 'CEO' 
                      ? AdminColors.navy.withValues(alpha: 0.1) 
                      : AdminColors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  role.toString().toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: role.toString().toUpperCase() == 'CEO' ? AdminColors.navy : AdminColors.darkAmber,
                  ),
                ),
              ),
              const Spacer(),
              if (createdAt != null)
                Text(
                  DateFormat('MMM dd, yyyy').format(createdAt),
                  style: AdminTheme.mutedStyle(size: 12),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(name, style: AdminTheme.titleStyle(size: 18)),
          const SizedBox(height: 8),
          _DetailRow(label: 'Original Rejection Reason', value: appeal['rejectionReason'] ?? 'None'),
          const Divider(height: 24),
          Text('APPEAL MESSAGE', style: AdminTheme.sectionHeaderStyle().copyWith(fontSize: 11)),
          const SizedBox(height: 8),
          Text(
            appeal['message'] ?? 'No message provided.',
            style: AdminTheme.bodyStyle(),
          ),
          if (appeal['phone'] != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 14, color: AdminColors.textGrey),
                const SizedBox(width: 6),
                Text(appeal['phone'], style: AdminTheme.mutedStyle(size: 13)),
              ],
            ),
          ],
          if (appeal['imageUrl'] != null) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: () => _showImageDialog(context, appeal['imageUrl']),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  appeal['imageUrl'],
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    color: Colors.grey.shade100,
                    child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
          if (status == 'pending') ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showConfirmDialog(context, 'Accept Appeal', 'This will restore the account to active status.', () => adminVM.acceptAppeal(appeal, appealId)),
                    style: AdminTheme.primaryButtonStyle(height: 44),
                    child: const Text('ACCEPT APPEAL'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showRejectDialog(context, adminVM, appeal, appealId),
                    style: AdminTheme.destructiveButtonStyle(height: 44),
                    child: const Text('REJECT'),
                  ),
                ),
              ],
            ),
          ] else ...[
            const Divider(height: 32),
            Row(
              children: [
                Icon(
                  status == 'accepted' ? Icons.check_circle_outline : Icons.cancel_outlined,
                  size: 16,
                  color: status == 'accepted' ? Colors.green : AdminColors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  'Decision: ${status.toUpperCase()}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    color: status == 'accepted' ? Colors.green : AdminColors.red,
                  ),
                ),
              ],
            ),
            if (appeal['adminResponse'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Admin Response: ${appeal['adminResponse']}',
                style: AdminTheme.mutedStyle(size: 13),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _showImageDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Document View'),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(BuildContext context, String title, String message, Future<void> Function() action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await action();
            },
            child: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.bold, color: AdminColors.navy)),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(BuildContext context, AdminViewModel adminVM, Map<String, dynamic> appeal, String appealId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Appeal'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason for rejection'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context);
              await adminVM.rejectAppeal(appeal, appealId, controller.text.trim());
            },
            child: const Text('REJECT APPEAL', style: TextStyle(fontWeight: FontWeight.bold, color: AdminColors.red)),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AdminTheme.mutedStyle(size: 11).copyWith(fontWeight: FontWeight.bold)),
          Text(value, style: AdminTheme.bodyStyle().copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}