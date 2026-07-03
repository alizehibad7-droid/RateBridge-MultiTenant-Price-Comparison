import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart';
import '../../theme/ceo_theme.dart';
import '../../models/partnership_request_model.dart';
import '../../models/supplier_model.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../widgets/ceo_nav_bar.dart';
import '../../widgets/ceo/ceo_widgets.dart';

class CeoInviteHubView extends StatefulWidget {
  const CeoInviteHubView({super.key});

  @override
  State<CeoInviteHubView> createState() => _CeoInviteHubViewState();
}

class _CeoInviteHubViewState extends State<CeoInviteHubView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _selectedCategory = 'All';
  String _selectedCity = 'All';
  bool _verifiedOnly = false;
  String _sortBy = 'Rating';
  final _searchController = TextEditingController();

  final List<String> _cities = [
    'All',
    'Lahore',
    'Karachi',
    'Islamabad',
    'Rawalpindi',
    'Faisalabad',
    'Multan',
    'Peshawar'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = Provider.of<CeoViewModel>(context, listen: false);
      final companyId = vm.company?.id;
      if (companyId != null && companyId.isNotEmpty) {
        vm.ensurePartnershipStatusWatch(companyId);
      }
      vm.loadMarketplace();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters(CeoViewModel vm) {
    vm.applyFilters(
      category: _selectedCategory == 'All' ? null : _selectedCategory,
      city: _selectedCity == 'All' ? null : _selectedCity,
      verifiedOnly: _verifiedOnly ? true : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<CeoViewModel>(context);
    final companyId = vm.company?.id ?? '';

    return Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: CeoAppBar(
        title: 'Supplier Hub',
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Marketplace'),
            Tab(text: 'Join Requests'),
            Tab(text: 'Sent'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (vm.errorMessage != null)
            Container(
              width: double.infinity,
              color: CeoColors.red.withValues(alpha: 0.1),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: CeoColors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      vm.errorMessage!,
                      style: GoogleFonts.plusJakartaSans(
                        color: CeoColors.red,
                        fontSize: 13,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 18, color: CeoColors.red),
                    onPressed: () => vm.clearMessages(),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMarketplace(vm, companyId),
                _buildJoinRequests(companyId),
                _buildSentRequests(companyId),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CeoNavBar(currentIndex: 2),
    );
  }

  Widget _buildMarketplace(CeoViewModel vm, String companyId) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Column(
            children: [
              TextField(
                key: const ValueKey('marketplace_supplier_search'),
                controller: _searchController,
                decoration: CeoTheme.inputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            vm.loadMarketplace();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (val) {
                  setState(() {});
                  vm.searchSuppliers(val);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _filterChip(
                      'Category',
                      _selectedCategory,
                      ['All', ...AppConstants.defaultCategories],
                      (v) {
                        setState(() => _selectedCategory = v);
                        _applyFilters(vm);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _filterChip(
                      'City',
                      _selectedCity,
                      _cities,
                      (v) {
                        setState(() => _selectedCity = v);
                        _applyFilters(vm);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: Text('Verified Only',
                          style: CeoTheme.mutedStyle(size: 12)),
                      selected: _verifiedOnly,
                      onSelected: (v) {
                        setState(() => _verifiedOnly = v);
                        _applyFilters(vm);
                      },
                      selectedColor: CeoColors.navy.withValues(alpha: 0.12),
                      checkmarkColor: CeoColors.navy,
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _sortBy,
                      underline: const SizedBox.shrink(),
                      isDense: true,
                      style: CeoTheme.mutedStyle(size: 12),
                      items: const [
                        DropdownMenuItem(
                            value: 'Rating',
                            child: Text('By Rating',
                                style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(
                            value: 'Name',
                            child: Text('By Name',
                                style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _sortBy = v);
                          vm.sortSuppliers(v);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: vm.isLoading && vm.marketplaceSuppliers.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : vm.marketplaceSuppliers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off,
                              size: 48, color: CeoColors.textGrey),
                          const SizedBox(height: 12),
                          Text('No suppliers found',
                              style: CeoTheme.mutedStyle()),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              _selectedCity = 'All';
                              _selectedCategory = 'All';
                              vm.loadMarketplace();
                              setState(() {});
                            },
                            child: const Text('Clear Filters'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: vm.marketplaceSuppliers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final supplier = vm.marketplaceSuppliers[i];
                        return _supplierCard(
                            context, vm, supplier, companyId);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _supplierCard(BuildContext context, CeoViewModel vm,
      SupplierModel supplier, String companyId) {
    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: CeoColors.navy.withValues(alpha: 0.12),
                child: Text(
                  supplier.name.isNotEmpty
                      ? supplier.name[0].toUpperCase()
                      : 'S',
                  style: GoogleFonts.plusJakartaSans(
                    color: CeoColors.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplier.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: CeoColors.navy,
                      ),
                    ),
                    Text(supplier.email,
                        style: CeoTheme.mutedStyle(size: 12)),
                    Text(supplier.city,
                        style: CeoTheme.mutedStyle(size: 12)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _ratingStars(supplier.rating),
                        const SizedBox(width: 6),
                        Text(
                          '${supplier.rating.toStringAsFixed(1)} (${supplier.activeContracts})',
                          style: CeoTheme.mutedStyle(size: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (supplier.isVerified) _verifiedBadge(),
            ],
          ),
          const SizedBox(height: 12),
          _buildPartnershipAction(context, vm, supplier, companyId),
        ],
      ),
    );
  }

  Widget _buildPartnershipAction(
    BuildContext context,
    CeoViewModel vm,
    SupplierModel supplier,
    String companyId,
  ) {
    final status = vm.linkStatusFor(supplier.id);
    if (status == 'Already Partners') {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          foregroundColor: CeoColors.green,
          side: const BorderSide(color: CeoColors.green),
        ),
        child: const Text('Already Partners'),
      );
    }
    if (status == 'Request Pending') {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          foregroundColor: CeoColors.textGrey,
        ),
        child: const Text('Request Pending'),
      );
    }
    if (status == 'Request Rejected') {
      final reason = vm.linkRejectionReasonFor(supplier.id);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reason != null && reason.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CeoColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Rejected: $reason',
                style: GoogleFonts.plusJakartaSans(
                  color: CeoColors.red,
                  fontSize: 12,
                ),
              ),
            ),
          ElevatedButton.icon(
            onPressed: () => _showPartnershipSheet(context, vm, supplier),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Send Again'),
            style: CeoTheme.primaryButtonStyle(height: 44),
          ),
        ],
      );
    }
    return ElevatedButton.icon(
      onPressed: () => _showPartnershipSheet(context, vm, supplier),
      icon: const Icon(Icons.send_outlined, size: 16),
      label: const Text('Send Partnership Request'),
      style: CeoTheme.primaryButtonStyle(height: 44),
    );
  }

  Widget _buildSentRequests(String companyId) {
    if (companyId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Consumer<CeoViewModel>(
      builder: (context, vm, _) {
        if (!vm.partnershipRequestsReady) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = vm.sentPartnershipRequests;
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.send_outlined,
                    size: 48, color: CeoColors.textGrey),
                const SizedBox(height: 12),
                Text('No sent partnership requests',
                    style: CeoTheme.mutedStyle()),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _sentRequestCard(requests[i]),
        );
      },
    );
  }

  Widget _sentRequestCard(PartnershipRequestModel req) {
    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  req.supplierName,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: CeoColors.navy,
                  ),
                ),
              ),
              CeoStatusBadge(status: req.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Sent: ${req.createdAt.toLocal().toString().split(' ').first}',
            style: CeoTheme.mutedStyle(size: 12),
          ),
          if (req.status == 'rejected' &&
              req.rejectionReason != null &&
              req.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CeoColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Rejection reason: ${req.rejectionReason}',
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

  Widget _buildJoinRequests(String companyId) {
    if (companyId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Consumer<CeoViewModel>(
      builder: (context, vm, _) {
        if (!vm.partnershipRequestsReady) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = vm.pendingReceivedPartnershipRequests;
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inbox_outlined,
                    size: 48, color: CeoColors.textGrey),
                const SizedBox(height: 12),
                Text('No pending join requests',
                    style: CeoTheme.mutedStyle()),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) =>
              _joinRequestCard(context, vm, requests[i]),
        );
      },
    );
  }

  Widget _joinRequestCard(
      BuildContext context, CeoViewModel vm, PartnershipRequestModel req) {
    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: CeoColors.navy.withValues(alpha: 0.12),
                child: Text(
                  req.supplierName.isNotEmpty
                      ? req.supplierName[0].toUpperCase()
                      : 'S',
                  style: GoogleFonts.plusJakartaSans(
                    color: CeoColors.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.supplierName,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: CeoColors.navy,
                      ),
                    ),
                    if (req.supplierEmail != null &&
                        req.supplierEmail!.isNotEmpty)
                      Text(req.supplierEmail!,
                          style: CeoTheme.mutedStyle(size: 12)),
                    if (req.supplierCity != null &&
                        req.supplierCity!.isNotEmpty)
                      Text(req.supplierCity!,
                          style: CeoTheme.mutedStyle(size: 12)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _ratingStars(req.supplierRating),
                        const SizedBox(width: 6),
                        Text(
                          req.supplierRating.toStringAsFixed(1),
                          style: CeoTheme.mutedStyle(size: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (req.message != null && req.message!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CeoColors.screenBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${req.message}"',
                style: GoogleFonts.plusJakartaSans(
                  fontStyle: FontStyle.italic,
                  color: CeoColors.textGrey,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () =>
                      vm.acceptPartnershipRequest(req.requestId),
                  style: CeoTheme.primaryButtonStyle(height: 44),
                  child: const Text('Accept Request'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      _showRejectDialog(context, vm, req.requestId),
                  style: CeoTheme.destructiveButtonStyle(height: 44),
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(
      BuildContext context, CeoViewModel vm, String reqId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject request'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: CeoTheme.inputDecoration(
            labelText: 'Reason',
            hintText: 'Let the supplier know why...',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          OutlinedButton(
            style: CeoTheme.destructiveButtonStyle(height: 40),
            onPressed: () {
              vm.rejectPartnershipRequest(
                  reqId, reasonController.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showPartnershipSheet(
    BuildContext context,
    CeoViewModel vm,
    SupplierModel supplier,
  ) {
    final messageController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: CeoColors.screenBg,
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
            Text('Partnership request', style: CeoTheme.titleStyle(size: 16)),
            const SizedBox(height: 8),
            Text(
              'Send a request to ${supplier.name}. They must accept before your field team can see their materials.',
              style: CeoTheme.mutedStyle(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: CeoTheme.inputDecoration(
                labelText: 'Optional message',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await vm.sendPartnershipRequest(
                  supplier.id,
                  message: messageController.text.trim().isEmpty
                      ? null
                      : messageController.text.trim(),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('Request sent to ${supplier.name}')),
                  );
                }
              },
              style: CeoTheme.primaryButtonStyle(height: 48),
              child: const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String current, List<String> options,
      void Function(String) onSelect) {
    final isActive = current != 'All' && current.isNotEmpty;
    return PopupMenuButton<String>(
      initialValue: current,
      onSelected: onSelect,
      itemBuilder: (_) =>
          options.map((o) => PopupMenuItem(value: o, child: Text(o))).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? CeoColors.navy.withValues(alpha: 0.12)
              : CeoColors.screenBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isActive ? CeoColors.navy : CeoColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (current == 'All' || current.isEmpty) ? label : current,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? CeoColors.navy : CeoColors.textGrey,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down,
                size: 16, color: CeoColors.textGrey),
          ],
        ),
      ),
    );
  }

  Widget _verifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CeoColors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Verified',
        style: GoogleFonts.plusJakartaSans(
          color: CeoColors.green,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _ratingStars(double value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          value >= i + 1
              ? Icons.star
              : value > i
                  ? Icons.star_half
                  : Icons.star_border,
          size: 14,
          color: CeoColors.amber,
        );
      }),
    );
  }
}
