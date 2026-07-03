// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../models/partnership_request_model.dart';
import '../../theme/ceo_theme.dart';
import '../../constants/route_names.dart';
import '../../widgets/ceo/ceo_widgets.dart';
import 'package:intl/intl.dart';

class CeoJoinRequestsView extends StatefulWidget {
  const CeoJoinRequestsView({super.key});

  @override
  State<CeoJoinRequestsView> createState() => _CeoJoinRequestsViewState();
}

class _CeoJoinRequestsViewState extends State<CeoJoinRequestsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<CeoViewModel>();
      final companyId = vm.company?.id;
      if (companyId != null && companyId.isNotEmpty) {
        vm.ensurePartnershipStatusWatch(companyId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ceoVM = context.watch<CeoViewModel>();
    final companyId = ceoVM.company?.id ?? '';

    return Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: CeoAppBar(
        title: 'Partnership Requests',
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push(RouteNames.ceoProfile),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Supplier requests'),
            Tab(text: 'Sent by you'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReceivedTab(ceoVM, companyId),
          _buildSentTab(ceoVM, companyId),
        ],
      ),
    );
  }

  Widget _buildReceivedTab(CeoViewModel viewModel, String companyId) {
    if (companyId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!viewModel.partnershipRequestsReady) {
      return const Center(child: CircularProgressIndicator());
    }

    final requests = viewModel.pendingReceivedPartnershipRequests;
    if (requests.isEmpty) {
      return Center(
        child: Text('No received requests.', style: CeoTheme.mutedStyle()),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildRequestCard(viewModel, requests[index]),
        );
      },
    );
  }

  Widget _buildSentTab(CeoViewModel viewModel, String companyId) {
    if (companyId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!viewModel.partnershipRequestsReady) {
      return const Center(child: CircularProgressIndicator());
    }

    final invites = viewModel.sentPartnershipRequests;
    if (invites.isEmpty) {
      return Center(
        child: Text('No sent invitations.', style: CeoTheme.mutedStyle()),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invites.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildInviteCard(invites[index]),
        );
      },
    );
  }

  Widget _buildRequestCard(
      CeoViewModel viewModel, PartnershipRequestModel req) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            req.supplierName,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: CeoColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Requested on: ${DateFormat('MMM dd, yyyy').format(req.createdAt)}',
            style: CeoTheme.mutedStyle(size: 12),
          ),
          if (req.message != null) ...[
            const SizedBox(height: 12),
            Text(req.message!, style: CeoTheme.bodyStyle()),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showRejectDialog(viewModel, req),
                  style: CeoTheme.destructiveButtonStyle(height: 44),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _confirmAccept(viewModel, req),
                  style: CeoTheme.primaryButtonStyle(height: 44),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCard(PartnershipRequestModel invite) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  invite.supplierName,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: CeoColors.navy,
                  ),
                ),
              ),
              CeoStatusBadge(status: invite.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Sent: ${DateFormat('MMM dd, yyyy').format(invite.createdAt)}',
            style: CeoTheme.mutedStyle(size: 12),
          ),
          if (invite.status == 'rejected' &&
              invite.rejectionReason != null &&
              invite.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CeoColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Rejection reason: ${invite.rejectionReason}',
                style: GoogleFonts.plusJakartaSans(
                  color: CeoColors.red,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmAccept(CeoViewModel viewModel, PartnershipRequestModel req) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Request'),
        content: Text(
            'Allow ${req.supplierName} to join your company network?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: CeoTheme.primaryButtonStyle(height: 40),
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.acceptPartnershipRequest(req.requestId);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(
      CeoViewModel viewModel, PartnershipRequestModel req) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: TextField(
          controller: reasonController,
          decoration: CeoTheme.inputDecoration(
            hintText: 'Reason for rejection',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            style: CeoTheme.destructiveButtonStyle(height: 40),
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.rejectPartnershipRequest(
                  req.requestId, reasonController.text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}
