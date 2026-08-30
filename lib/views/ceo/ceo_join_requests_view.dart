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
  late final TabController _tabController;

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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: CeoColors.amber,
          indicatorWeight: 3,
          labelColor: CeoColors.navy,
          unselectedLabelColor: CeoColors.textGrey,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(
              icon: Icon(Icons.handshake_rounded, size: 20),
              text: 'Incoming',
            ),
            Tab(
              icon: Icon(Icons.outbox_rounded, size: 20),
              text: 'Outgoing',
            ),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: CeoColors.navy.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inbox_rounded, size: 64, color: CeoColors.textGrey),
            ),
            const SizedBox(height: 16),
            Text('No incoming requests', style: CeoTheme.titleStyle(size: 18).copyWith(color: CeoColors.textGrey)),
            Text('Requests from suppliers will appear here', style: CeoTheme.mutedStyle()),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildRequestCard(viewModel, requests[index]);
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: CeoColors.navy.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, size: 64, color: CeoColors.textGrey),
            ),
            const SizedBox(height: 16),
            Text('No outgoing requests', style: CeoTheme.titleStyle(size: 18).copyWith(color: CeoColors.textGrey)),
            Text('Invite suppliers to see them here', style: CeoTheme.mutedStyle()),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: invites.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildInviteCard(invites[index]);
      },
    );
  }

  Widget _buildRequestCard(
      CeoViewModel viewModel, PartnershipRequestModel req) {
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: CeoColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    req.supplierName.isNotEmpty ? req.supplierName[0].toUpperCase() : 'S',
                    style: GoogleFonts.plusJakartaSans(
                      color: CeoColors.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
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
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: CeoColors.textGrey),
                        const SizedBox(width: 4),
                        Text(
                          'Requested ${DateFormat('MMM dd, yyyy').format(req.createdAt)}',
                          style: CeoTheme.mutedStyle(size: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (req.message != null && req.message!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CeoColors.screenBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CeoColors.border),
              ),
              child: Text(
                '"${req.message}"',
                style: GoogleFonts.plusJakartaSans(
                  fontStyle: FontStyle.italic,
                  color: CeoColors.navy,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRejectDialog(viewModel, req),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('DECLINE'),
                  style: CeoTheme.destructiveButtonStyle(height: 48),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _confirmAccept(viewModel, req),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('APPROVE'),
                  style: CeoTheme.primaryButtonStyle(height: 48),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CeoColors.navy.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.store_rounded, color: CeoColors.navy, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.supplierName,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: CeoColors.navy,
                      ),
                    ),
                    Text(
                      'Sent ${DateFormat('MMM dd, yyyy').format(invite.createdAt)}',
                      style: CeoTheme.mutedStyle(size: 11),
                    ),
                  ],
                ),
              ),
              CeoStatusBadge(status: invite.status),
            ],
          ),
          if (invite.status == 'rejected' &&
              invite.rejectionReason != null &&
              invite.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CeoColors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CeoColors.red.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: CeoColors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason: ${invite.rejectionReason}',
                      style: GoogleFonts.plusJakartaSans(
                        color: CeoColors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
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
        title: Row(
          children: [
            const Icon(Icons.handshake_rounded, color: CeoColors.green),
            const SizedBox(width: 10),
            const Text('Accept Request'),
          ],
        ),
        content: Text('Allow ${req.supplierName} to join your company network? They will be able to see your company details.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton.icon(
            style: CeoTheme.primaryButtonStyle(height: 40).copyWith(
              backgroundColor: WidgetStateProperty.all(CeoColors.green),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.acceptPartnershipRequest(req.requestId);
            },
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('CONFIRM'),
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
        title: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: CeoColors.red),
            const SizedBox(width: 10),
            const Text('Decline Request'),
          ],
        ),
        content: TextField(
          controller: reasonController,
          decoration: CeoTheme.inputDecoration(
            labelText: 'Reason (Optional)',
            hintText: 'e.g. Identity not verified...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          OutlinedButton.icon(
            style: CeoTheme.destructiveButtonStyle(height: 40),
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.rejectPartnershipRequest(
                  req.requestId, reasonController.text.trim());
            },
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('DECLINE'),
          ),
        ],
      ),
    );
  }
}
