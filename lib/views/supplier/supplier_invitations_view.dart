// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../models/invitation_model.dart';
import '../../constants/app_colors.dart';
import 'package:intl/intl.dart';

class SupplierInvitationsView extends StatefulWidget {
  const SupplierInvitationsView({super.key});

  @override
  State<SupplierInvitationsView> createState() => _SupplierInvitationsViewState();
}

class _SupplierInvitationsViewState extends State<SupplierInvitationsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierViewModel>().loadInvitations();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<SupplierViewModel>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Invitations', style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Accepted'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInvitationList(viewModel, 'pending'),
          _buildInvitationList(viewModel, 'accepted'),
          _buildInvitationList(viewModel, 'all'),
        ],
      ),
    );
  }

  Widget _buildInvitationList(SupplierViewModel viewModel, String filter) {
    final list = filter == 'all' 
        ? viewModel.invitations 
        : viewModel.invitations.where((i) => i.status == filter).toList();

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No ${filter == 'all' ? '' : filter} invitations found', 
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final invite = list[index];
        return _buildInvitationCard(viewModel, invite);
      },
    );
  }

  Widget _buildInvitationCard(SupplierViewModel viewModel, InvitationModel invite) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                      Text(invite.companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const Text('City: Global', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                _statusBadge(invite.status),
              ],
            ),
            const SizedBox(height: 12),
            Text('Sent on: ${DateFormat('MMM dd, yyyy').format(invite.createdAt)}', 
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            if (invite.status == 'pending') ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _confirmDecline(viewModel, invite),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _confirmAccept(viewModel, invite),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color = Colors.amber;
    if (status == 'accepted') color = Colors.green;
    if (status == 'rejected') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _confirmAccept(SupplierViewModel viewModel, InvitationModel invite) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Invitation'),
        content: Text('Join ${invite.companyName} as a supplier?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.acceptInvitation(invite.token, invite.companyId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Welcome to ${invite.companyName}!'))
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
  }

  void _confirmDecline(SupplierViewModel viewModel, InvitationModel invite) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Invitation'),
        content: Text('Are you sure you want to decline the invitation from ${invite.companyName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.rejectInvitation(invite.token);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DECLINE'),
          ),
        ],
      ),
    );
  }
}
