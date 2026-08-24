import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../constants/route_names.dart';
import '../../../models/company_model.dart';
import '../../../models/partnership_request_model.dart';
import '../../../theme/supplier_theme.dart';
import '../../../utils/currency_formatter.dart';
import '../../../viewmodels/supplier_viewmodel.dart';
import '../../../widgets/supplier/supplier_async_states.dart';
import 'partnership_ui.dart';

class SupplierPartnershipsHubView extends StatefulWidget {
  final int initialTab;

  const SupplierPartnershipsHubView({super.key, this.initialTab = 0});

  @override
  State<SupplierPartnershipsHubView> createState() =>
      _SupplierPartnershipsHubViewState();
}

class _SupplierPartnershipsHubViewState
    extends State<SupplierPartnershipsHubView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierViewModel>().loadPartnershipHubData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _browseCompanies() => context.push(RouteNames.supplierCompanyDirectory);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SupplierViewModel>();
    final receivedCount = vm.pendingCeoInvitations.length;
    final sentCount = vm.pendingSupplierSentRequests.length;

    return Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: AppBar(
        title: const Text('Companies & Partnerships'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: FieldColors.accentAmber,
          unselectedLabelColor: Colors.white70,
          indicatorColor: FieldColors.accentAmber,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          tabs: [
            const Tab(text: 'Partners'),
            Tab(
              child: _TabWithBadge(
                label: 'Requests',
                count: receivedCount,
              ),
            ),
            Tab(
              child: _TabWithBadge(
                label: 'Sent',
                count: sentCount,
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ActivePartnersTab(vm: vm, onBrowse: _browseCompanies),
          _ReceivedRequestsTab(vm: vm, onBrowse: _browseCompanies),
          _SentRequestsTab(vm: vm, onBrowse: _browseCompanies),
        ],
      ),
    );
  }
}

class _TabWithBadge extends StatelessWidget {
  final String label;
  final int count;

  const _TabWithBadge({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: FieldColors.accentAmber,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: FieldColors.primaryNavy,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActivePartnersTab extends StatelessWidget {
  final SupplierViewModel vm;
  final VoidCallback onBrowse;

  const _ActivePartnersTab({required this.vm, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    if (!vm.partnershipHubDataLoaded && vm.activePartnerCompanies.isEmpty) {
      return const SupplierListSkeleton(itemCount: 3, itemHeight: 180);
    }
    if (vm.activePartnerCompanies.isEmpty) {
      return ListView(
        children: [
          partnershipEmptyState(
            icon: Icons.handshake_outlined,
            title: 'No Active Partnerships Yet',
            subtitle:
                'Browse companies and send a partnership request, or wait for companies to invite you.',
            buttonLabel: 'Browse Companies',
            onBrowse: onBrowse,
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: vm.activePartnerCompanies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _ActivePartnerCard(
        company: vm.activePartnerCompanies[index],
        vm: vm,
      ),
    );
  }
}

class _ActivePartnerCard extends StatelessWidget {
  final CompanyModel company;
  final SupplierViewModel vm;

  const _ActivePartnerCard({required this.company, required this.vm});

  @override
  Widget build(BuildContext context) {
    final stats = vm.partnerStatsFor(company.id);
    final subtitle = [
      if (company.city.isNotEmpty) company.city,
      if (company.companyType != null && company.companyType!.isNotEmpty)
        company.companyType!,
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: partnershipCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              companyInitialsAvatar(company.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: FieldColors.primaryNavy,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: FieldColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: FieldColors.statusSuccess.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Partner',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: FieldColors.statusSuccess,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniStat(
                icon: Icons.inventory_2_outlined,
                label: 'Total Orders',
                value: '${stats.totalOrders}',
              ),
              _MiniStat(
                icon: Icons.star_outline_rounded,
                label: 'Avg Rating',
                value: stats.avgRating > 0
                    ? stats.avgRating.toStringAsFixed(1)
                    : '—',
              ),
              _MiniStat(
                icon: Icons.payments_outlined,
                label: 'Total Earnings',
                value: CurrencyFormatter.formatPKR(stats.totalEarnings),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    vm.openCompanyContext(company.id);
                    context.go(RouteNames.supplierOrders);
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    foregroundColor: FieldColors.primaryNavy,
                  ),
                  child: const Text('View Orders', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    vm.openCompanyContext(company.id);
                    context.go(RouteNames.supplierChat);
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    foregroundColor: FieldColors.primaryNavy,
                  ),
                  child: const Text('Chat', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showRemoveSheet(context, company),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    foregroundColor: FieldColors.statusDanger,
                    side: const BorderSide(color: FieldColors.statusDanger),
                  ),
                  child: const Text('Remove', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRemoveSheet(BuildContext context, CompanyModel company) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: FieldColors.accentAmber, size: 48),
            const SizedBox(height: 16),
            Text(
              'Remove Partnership?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: FieldColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Removing ${company.name} means their field users will no longer see your materials or be able to place orders with you. This cannot be undone automatically — you\'ll need to send a new request to reconnect.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: FieldColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FieldColors.statusDanger,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final name = await vm.removePartnership(company.id);
                      if (context.mounted && name != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Partnership with $name removed.')),
                        );
                      }
                    },
                    child: const Text('Yes, Remove'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: FieldColors.textSecondary),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: FieldColors.primaryNavy,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              color: FieldColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceivedRequestsTab extends StatelessWidget {
  final SupplierViewModel vm;
  final VoidCallback onBrowse;

  const _ReceivedRequestsTab({required this.vm, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    if (!vm.partnershipListsReady) {
      return const SupplierListSkeleton(itemCount: 4, itemHeight: 120);
    }

    final received = vm.pendingCeoInvitations;

    if (received.isEmpty) {
      return ListView(
        children: [
          partnershipEmptyState(
            icon: Icons.mail_outline,
            title: 'No Partnership Invitations',
            subtitle:
                'You haven\'t received any partnership invitations from companies yet.',
            buttonLabel: 'Browse Companies',
            onBrowse: onBrowse,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: received.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _InvitationCard(request: received[index], vm: vm),
    );
  }
}

class _SentRequestsTab extends StatelessWidget {
  final SupplierViewModel vm;
  final VoidCallback onBrowse;

  const _SentRequestsTab({required this.vm, required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    if (!vm.partnershipListsReady) {
      return const SupplierListSkeleton(itemCount: 4, itemHeight: 120);
    }

    final sent = vm.pendingSupplierSentRequests;
    final past = vm.pastPartnershipRequests;

    if (sent.isEmpty && past.isEmpty) {
      return ListView(
        children: [
          partnershipEmptyState(
            icon: Icons.send_outlined,
            title: 'No Sent Requests',
            subtitle:
                'You haven\'t sent any partnership requests to companies. Start browsing to connect!',
            buttonLabel: 'Browse Companies',
            onBrowse: onBrowse,
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (sent.isNotEmpty) ...[
          partnershipSectionHeader('Active Requests'),
          ...sent.map((r) => _SentRequestCard(request: r, vm: vm)),
          const SizedBox(height: 16),
        ],
        if (past.isNotEmpty) ...[
          partnershipSectionHeader('History'),
          ...past.map((r) => _PastRequestCard(request: r, vm: vm)),
        ],
      ],
    );
  }
}

class _InvitationCard extends StatelessWidget {
  final PartnershipRequestModel request;
  final SupplierViewModel vm;

  const _InvitationCard({required this.request, required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: partnershipCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            request.companyName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: FieldColors.primaryNavy,
            ),
          ),
          if (request.message != null && request.message!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FieldColors.screenBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${request.message}"',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: FieldColors.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Received ${partnershipDaysAgo(request.createdAt)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: FieldColors.accentAmber,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final name =
                        await vm.acceptPartnershipRequest(request.requestId);
                    if (context.mounted && name != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Partnership accepted with $name'),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 36)),
                  child: const Text('Accept'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _declineSheet(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    foregroundColor: FieldColors.statusDanger,
                    side: const BorderSide(color: FieldColors.statusDanger),
                  ),
                  child: const Text('Decline'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _declineSheet(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Decline invitation',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason for declining (optional)',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FieldColors.statusDanger,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await vm.rejectPartnershipRequest(
                  request.requestId,
                  controller.text.trim(),
                );
                if (context.mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Request declined.')),
                  );
                }
              },
              child: const Text('Confirm Decline'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SentRequestCard extends StatelessWidget {
  final PartnershipRequestModel request;
  final SupplierViewModel vm;

  const _SentRequestCard({required this.request, required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: partnershipCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.companyName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: FieldColors.primaryNavy,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: FieldColors.accentAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Pending Approval',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: FieldColors.primaryNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Waiting for Company Approval',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: FieldColors.accentAmber,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sent ${partnershipDaysAgo(request.createdAt)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: FieldColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Withdraw request?'),
                    content: const Text(
                      'This will cancel your pending partnership request.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Withdraw'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await vm.withdrawPartnershipRequest(request.requestId);
                }
              },
              icon: const Icon(Icons.cancel_outlined, size: 14),
              label: const Text('Withdraw Request', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: FieldColors.statusDanger,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PastRequestCard extends StatelessWidget {
  final PartnershipRequestModel request;
  final SupplierViewModel vm;

  const _PastRequestCard({required this.request, required this.vm});

  @override
  Widget build(BuildContext context) {
    final label = vm.pastRequestStatusLabel(request);
    final closedAt = request.respondedAt ?? request.createdAt;
    final canRetry = request.status == 'rejected' &&
        vm.canReapplyToCompany(request.companyId);

    Color badgeColor = FieldColors.textSecondary;
    if (label == 'Declined by Them') badgeColor = FieldColors.statusDanger;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: partnershipCardDecoration(
        borderColor: FieldColors.borderSubtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.companyName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FieldColors.textSecondary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Closed ${partnershipDaysAgo(closedAt)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: FieldColors.textMuted,
            ),
          ),
          if (request.rejectionReason != null &&
              request.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              request.rejectionReason!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: FieldColors.textSecondary,
              ),
            ),
          ],
          if (canRetry) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: () => context.push(RouteNames.supplierCompanyDirectory),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 32)),
                child: const Text('Send New Request', style: TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
