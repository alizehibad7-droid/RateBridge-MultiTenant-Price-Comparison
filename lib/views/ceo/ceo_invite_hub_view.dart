import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_constants.dart' as constants;
import '../../theme/ceo_theme.dart';
import '../../models/partnership_request_model.dart';
import '../../models/supplier_model.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../widgets/ceo_nav_bar.dart';
import '../../widgets/ceo/ceo_widgets.dart';
import '../../utils/formatters.dart';

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
          indicatorColor: CeoColors.amber,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: CeoColors.textGrey,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(
              icon: Icon(Icons.shopping_basket_rounded, size: 20),
              text: 'Marketplace',
            ),
            Tab(
              icon: Icon(Icons.handshake_rounded, size: 20),
              text: 'Join Requests',
            ),
            Tab(
              icon: Icon(Icons.outbox_rounded, size: 20),
              text: 'Sent',
            ),
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
                  const Icon(Icons.error_outline_rounded,
                      color: CeoColors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      vm.errorMessage!,
                      style: GoogleFonts.plusJakartaSans(
                        color: CeoColors.red,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              TextField(
                key: const ValueKey('marketplace_supplier_search'),
                controller: _searchController,
                style: GoogleFonts.plusJakartaSans(fontSize: 14),
                decoration: CeoTheme.inputDecoration(
                  hintText: 'Search by business name...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 22, color: CeoColors.navy),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded, size: 20, color: CeoColors.textGrey),
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
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _filterChip(
                      Icons.category_outlined,
                      'Category',
                      _selectedCategory,
                      ['All', ...constants.AppConstants.defaultCategories],
                      (v) {
                        setState(() => _selectedCategory = v);
                        _applyFilters(vm);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _filterChip(
                      Icons.location_on_outlined,
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
              const SizedBox(height: 12),
              Row(
                children: [
                  FilterChip(
                    avatar: Icon(
                      _verifiedOnly ? Icons.verified_rounded : Icons.verified_outlined,
                      size: 16,
                      color: _verifiedOnly ? CeoColors.navy : CeoColors.textGrey,
                    ),
                    label: Text('Verified Only',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: _verifiedOnly ? FontWeight.w700 : FontWeight.w500,
                          color: _verifiedOnly ? CeoColors.navy : CeoColors.textGrey,
                        )),
                    selected: _verifiedOnly,
                    onSelected: (v) {
                      setState(() => _verifiedOnly = v);
                      _applyFilters(vm);
                    },
                    backgroundColor: CeoColors.screenBg,
                    selectedColor: CeoColors.navy.withValues(alpha: 0.1),
                    checkmarkColor: CeoColors.navy,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(color: _verifiedOnly ? CeoColors.navy : CeoColors.border),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: CeoColors.screenBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: CeoColors.border),
                    ),
                    child: DropdownButton<String>(
                      value: _sortBy,
                      underline: const SizedBox.shrink(),
                      isDense: true,
                      icon: const Icon(Icons.sort_rounded, size: 16, color: CeoColors.navy),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CeoColors.navy,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'Rating',
                            child: Text('By Rating')),
                        DropdownMenuItem(
                            value: 'Name',
                            child: Text('By Name')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _sortBy = v);
                          vm.sortSuppliers(v);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: vm.isLoading && vm.marketplaceSuppliers.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : vm.marketplaceSuppliers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off_rounded,
                              size: 64, color: CeoColors.textGrey),
                          const SizedBox(height: 16),
                          Text('No matching suppliers found',
                              style: CeoTheme.titleStyle(size: 16)),
                          const SizedBox(height: 8),
                          Text('Try adjusting your filters or search terms',
                              style: CeoTheme.mutedStyle()),
                          const SizedBox(height: 20),
                          TextButton.icon(
                            onPressed: () {
                              _searchController.clear();
                              _selectedCity = 'All';
                              _selectedCategory = 'All';
                              _verifiedOnly = false;
                              vm.loadMarketplace();
                              setState(() {});
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reset All Filters'),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: CeoColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    supplier.name.isNotEmpty
                        ? supplier.name[0].toUpperCase()
                        : 'S',
                    style: GoogleFonts.plusJakartaSans(
                      color: CeoColors.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            supplier.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: CeoColors.navy,
                            ),
                          ),
                        ),
                        if (supplier.isVerified) 
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.verified_rounded, color: CeoColors.green, size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _iconLabelRow(Icons.email_outlined, supplier.email),
                    const SizedBox(height: 2),
                    _iconLabelRow(Icons.location_on_outlined, supplier.city),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _ratingStars(supplier.rating),
                        const SizedBox(width: 8),
                        Text(
                          supplier.rating.toStringAsFixed(1),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: CeoColors.navy,
                          ),
                        ),
                        Text(
                          ' (${supplier.activeContracts} connections)',
                          style: CeoTheme.mutedStyle(size: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPartnershipAction(context, vm, supplier, companyId),
        ],
      ),
    );
  }

  Widget _iconLabelRow(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: CeoColors.textGrey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: CeoTheme.mutedStyle(size: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
      return Container(
        height: 44,
        width: double.infinity,
        decoration: BoxDecoration(
          color: CeoColors.green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CeoColors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.handshake_rounded, color: CeoColors.green, size: 18),
            const SizedBox(width: 8),
            Text(
              'Linked Partner',
              style: GoogleFonts.plusJakartaSans(
                color: CeoColors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    if (status == 'Request Pending') {
      return Container(
        height: 44,
        width: double.infinity,
        decoration: BoxDecoration(
          color: CeoColors.amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CeoColors.amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_bottom_rounded, color: CeoColors.darkAmber, size: 18),
            const SizedBox(width: 8),
            Text(
              'Awaiting Response',
              style: GoogleFonts.plusJakartaSans(
                color: CeoColors.darkAmber,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    if (status == 'Request Rejected') {
      final reason = vm.linkRejectionReasonFor(supplier.id);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reason != null && reason.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
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
                      'Rejected: $reason',
                      style: GoogleFonts.plusJakartaSans(
                        color: CeoColors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ElevatedButton.icon(
            onPressed: () => _showPartnershipSheet(context, vm, supplier),
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Resend Partnership Request'),
            style: CeoTheme.primaryButtonStyle(height: 44),
          ),
        ],
      );
    }
    return ElevatedButton.icon(
      onPressed: () => _showPartnershipSheet(context, vm, supplier),
      icon: const Icon(Icons.person_add_rounded, size: 18),
      label: const Text('Request Partnership'),
      style: CeoTheme.primaryButtonStyle(height: 48),
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

        final requests = vm.pendingSentPartnershipRequests;
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.send_rounded,
                    size: 64, color: CeoColors.textGrey),
                const SizedBox(height: 16),
                Text('No outgoing requests',
                    style: CeoTheme.titleStyle(size: 16)),
                Text('When you invite suppliers, they appear here',
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CeoColors.navy.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.outgoing_mail, color: CeoColors.navy, size: 20),
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
                        fontSize: 15,
                        color: CeoColors.navy,
                      ),
                    ),
                    if (req.supplierCity != null && req.supplierCity!.isNotEmpty)
                      Text(
                        req.supplierCity!,
                        style: CeoTheme.mutedStyle(size: 12),
                      ),
                  ],
                ),
              ),
              CeoStatusBadge(status: req.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 12, color: CeoColors.textGrey),
              const SizedBox(width: 6),
              Text(
                'Sent on ${AppFormatters.date(req.createdAt)}',
                style: CeoTheme.mutedStyle(size: 11),
              ),
            ],
          ),
          if (req.status == 'rejected' &&
              req.rejectionReason != null &&
              req.rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CeoColors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CeoColors.red.withValues(alpha: 0.1)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: CeoColors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rejection reason: ${req.rejectionReason}',
                      style: GoogleFonts.plusJakartaSans(
                        color: CeoColors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
                const Icon(Icons.mark_as_unread_rounded,
                    size: 64, color: CeoColors.textGrey),
                const SizedBox(height: 16),
                Text('No incoming requests',
                    style: CeoTheme.titleStyle(size: 16)),
                Text('Suppliers wanting to join will appear here',
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: CeoColors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    req.supplierName.isNotEmpty
                        ? req.supplierName[0].toUpperCase()
                        : 'S',
                    style: GoogleFonts.plusJakartaSans(
                      color: CeoColors.darkAmber,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
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
                    if (req.supplierEmail != null &&
                        req.supplierEmail!.isNotEmpty)
                      _iconLabelRow(Icons.email_outlined, req.supplierEmail!),
                    if (req.supplierCity != null &&
                        req.supplierCity!.isNotEmpty)
                      _iconLabelRow(Icons.location_on_outlined, req.supplierCity!),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _ratingStars(req.supplierRating),
                        const SizedBox(width: 8),
                        Text(
                          req.supplierRating.toStringAsFixed(1),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: CeoColors.navy,
                          ),
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
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CeoColors.screenBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CeoColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: CeoColors.textGrey),
                      const SizedBox(width: 6),
                      Text('Message from Supplier', style: CeoTheme.mutedStyle(size: 11).copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '"${req.message}"',
                    style: GoogleFonts.plusJakartaSans(
                      fontStyle: FontStyle.italic,
                      color: CeoColors.navy,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      vm.acceptPartnershipRequest(req.requestId),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Approve'),
                  style: CeoTheme.primaryButtonStyle(height: 48),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showRejectDialog(context, vm, req.requestId),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Decline'),
                  style: CeoTheme.destructiveButtonStyle(height: 48),
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
        title: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: CeoColors.red),
            const SizedBox(width: 10),
            const Text('Decline Request'),
          ],
        ),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: CeoTheme.inputDecoration(
            labelText: 'Reason (Optional)',
            hintText: 'Provide context for rejection...',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Pending')),
          OutlinedButton.icon(
            style: CeoTheme.destructiveButtonStyle(height: 40),
            onPressed: () {
              vm.rejectPartnershipRequest(
                  reqId, reasonController.text.trim());
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Reject Permanently'),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.handshake_outlined, color: CeoColors.navy, size: 24),
                const SizedBox(width: 12),
                Text('Invite to Partnership', style: CeoTheme.titleStyle(size: 20)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Send a formal request to link ${supplier.name} to your company workflow.',
              style: CeoTheme.mutedStyle(size: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: messageController,
              maxLines: 4,
              decoration: CeoTheme.inputDecoration(
                labelText: 'Add an optional message',
                hintText: 'Introduce your company or specify project needs...',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
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
                      behavior: SnackBarBehavior.floating,
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          Text('Request sent to ${supplier.name}'),
                        ],
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text('Send Formal Request'),
              style: CeoTheme.primaryButtonStyle(height: 52),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(IconData icon, String label, String current, List<String> options,
      void Function(String) onSelect) {
    final isActive = current != 'All' && current.isNotEmpty;
    return PopupMenuButton<String>(
      initialValue: current,
      onSelected: onSelect,
      offset: const Offset(0, 45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) =>
          options.map((o) => PopupMenuItem(
            value: o, 
            child: Row(
              children: [
                Icon(current == o ? Icons.check_circle_rounded : Icons.circle_outlined, 
                  size: 16, color: current == o ? CeoColors.amber : CeoColors.textGrey),
                const SizedBox(width: 12),
                Text(o, style: GoogleFonts.plusJakartaSans(fontSize: 14)),
              ],
            ))).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? CeoColors.navy.withValues(alpha: 0.08)
              : CeoColors.screenBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isActive ? CeoColors.navy : CeoColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isActive ? CeoColors.navy : CeoColors.textGrey),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (current == 'All' || current.isEmpty) ? label : current,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? CeoColors.navy : CeoColors.textGrey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: CeoColors.textGrey),
          ],
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
              ? Icons.star_rounded
              : value > i
                  ? Icons.star_half_rounded
                  : Icons.star_border_rounded,
          size: 16,
          color: CeoColors.amber,
        );
      }),
    );
  }
}
