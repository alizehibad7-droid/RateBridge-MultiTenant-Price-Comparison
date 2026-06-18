import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../models/user_model.dart';
import '../../models/company_model.dart';
import '../../constants/app_colors.dart';

class AdminCeoManagementView extends StatefulWidget {
  const AdminCeoManagementView({super.key});

  @override
  State<AdminCeoManagementView> createState() => _AdminCeoManagementViewState();
}

class _AdminCeoManagementViewState extends State<AdminCeoManagementView> with SingleTickerProviderStateMixin {
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
      appBar: AppBar(
        title: const Text('CEO Management', style: TextStyle(fontWeight: FontWeight.bold)),
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
      stream: FirebaseFirestore.instance.collection('users')
          .where('role', isEqualTo: 'CEO')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Text('No $status CEOs found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final ceo = UserModel.fromMap(docs[index].data() as Map<String, dynamic>);
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('companies').doc(ceo.companyId).get(),
              builder: (context, companySnap) {
                CompanyModel? company;
                if (companySnap.hasData && companySnap.data!.exists) {
                  company = CompanyModel.fromMap(companySnap.data!.data() as Map<String, dynamic>);
                }
                return _buildCeoCard(ceo, company, adminVM);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCeoCard(UserModel ceo, CompanyModel? company, AdminViewModel adminVM) {
    final status = (ceo.status ?? 'pending').toLowerCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ceo.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(ceo.email, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      if (company != null) Text("Company: ${company.name}", style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                    ],
                  ),
                ),
                _buildStatusBadge(status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(ceo.city, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(width: 16),
                const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(DateFormat('MMM d, yyyy').format(ceo.createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const Divider(height: 24),
            _buildActionButtons(company, ceo, adminVM),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'active': color = Colors.green; break;
      case 'pending': color = Colors.orange; break;
      case 'suspended': color = Colors.red; break;
      case 'rejected': color = Colors.red; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }

  Widget _buildActionButtons(CompanyModel? company, UserModel ceo, AdminViewModel adminVM) {
    final status = (ceo.status ?? 'pending').toLowerCase();

    return Wrap(
      spacing: 8,
      children: [
        if (status == 'pending') ...[
          ElevatedButton(
            onPressed: () => _showConfirmDialog(
              'Approve CEO',
              'Activate account and grant access?',
              () => adminVM.acceptCEO(company?.id, ceo.uid),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 0),
            child: const Text('Approve'),
          ),
          OutlinedButton(
            onPressed: () => _showRejectDialog(company?.id, ceo.uid, adminVM),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
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
            style: OutlinedButton.styleFrom(foregroundColor: Colors.amber, side: const BorderSide(color: Colors.amber)),
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
            style: OutlinedButton.styleFrom(foregroundColor: Colors.green, side: const BorderSide(color: Colors.green)),
            child: const Text('Activate'),
          ),
        ],
      ],
    );
  }

  void _showConfirmDialog(String title, String message, Future<void> Function() action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await action();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(String? companyId, String ceoUid, AdminViewModel adminVM) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Application'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Reason for rejection'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              adminVM.rejectCEO(companyId, ceoUid, reasonController.text);
              Navigator.pop(context);
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
