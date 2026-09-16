// MVVM: View — no business logic

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../constants/route_names.dart';
import '../../models/supplier_model.dart';
import '../../theme/ceo_theme.dart';
import '../../utils/app_navigation.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../widgets/ceo_nav_bar.dart';
import '../../widgets/ceo/ceo_widgets.dart';
import '../../widgets/supplier_performance_scorecard.dart';

const _citiesAll = [
  'All',
  'Rawalpindi',
  'Islamabad',
  'Lahore',
  'Karachi',
  'Peshawar',
];

class CeoMySuppliersView extends StatefulWidget {
  const CeoMySuppliersView({super.key});

  @override
  State<CeoMySuppliersView> createState() => _CeoMySuppliersViewState();
}

class _CeoMySuppliersViewState extends State<CeoMySuppliersView>
    with SingleTickerProviderStateMixin {
  late final TabController _cityTabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cityTabController = TabController(length: _citiesAll.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<CeoViewModel>();
      final companyId =
          context.read<AuthViewModel>().user?.companyId ?? vm.company?.id ?? '';
      if (companyId.isNotEmpty) {
        vm.ensurePartnershipStatusWatch(companyId);
      }
      vm.loadMarketplace();
    });
  }

  @override
  void dispose() {
    _cityTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<SupplierModel> _filterSuppliers(
    List<SupplierModel> all,
    String selectedCity,
  ) {
    var result = all;

    if (selectedCity != 'All') {
      final targetCity = selectedCity.trim().toLowerCase();
      result = result
          .where((s) => s.city.trim().toLowerCase() == targetCity)
          .toList();
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((s) => _matchesSearch(s, query)).toList();
    }
    return result;
  }

  bool _matchesSearch(SupplierModel supplier, String query) {
    final haystacks = [
      supplier.name,
      supplier.email,
      supplier.city,
      supplier.materialType,
      supplier.ownerFullName,
    ];
    for (final value in haystacks) {
      if ((value ?? '').toString().toLowerCase().contains(query)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final companyId = context.read<AuthViewModel>().user?.companyId ?? '';

    return RootTabPopScope(
      isHome: false,
      homeRoute: RouteNames.ceoDashboard,
      child: Scaffold(
        backgroundColor: CeoColors.screenBg,
        appBar: CeoAppBar(
          title: 'Partner Directory',
          bottom: TabBar(
            controller: _cityTabController,
            isScrollable: true,
            indicatorColor: CeoColors.amber,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: CeoColors.textGrey,
            labelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            tabs: _citiesAll.map((c) => Tab(text: c)).toList(),
          ),
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: GoogleFonts.plusJakartaSans(fontSize: 14),
                decoration: CeoTheme.inputDecoration(
                  hintText: 'Search by business name...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: CeoColors.navy,
                    size: 22,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            size: 20,
                            color: CeoColors.textGrey,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: Consumer<CeoViewModel>(
                builder: (context, vm, _) {
                  if (vm.isLoading && vm.marketplaceSuppliers.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return TabBarView(
                    controller: _cityTabController,
                    children: _citiesAll.map((city) {
                      final suppliers =
                          _filterSuppliers(vm.marketplaceSuppliers, city);
                      if (suppliers.isEmpty) {
                        return _EmptyDirectoryState(
                          hasSearch: _searchQuery.trim().isNotEmpty,
                          city: city,
                          onRetry: () => vm.loadMarketplace(),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () => vm.loadMarketplace(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: suppliers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) => _DirectorySupplierCard(
                            supplier: suppliers[i],
                            companyId: companyId,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: const CeoNavBar(currentIndex: 1),
      ),
    );
  }
}

class _EmptyDirectoryState extends StatelessWidget {
  final bool hasSearch;
  final String city;
  final VoidCallback onRetry;

  const _EmptyDirectoryState({
    required this.hasSearch,
    required this.city,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CeoColors.navy.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasSearch ? Icons.search_off_rounded : Icons.store_rounded,
              size: 48,
              color: CeoColors.textGrey,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch
                ? 'No matches found'
                : (city == 'All'
                    ? 'No active suppliers on the platform yet'
                    : 'No suppliers in $city'),
            style: CeoTheme.titleStyle(size: 16).copyWith(
              color: CeoColors.textGrey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}

class _DirectorySupplierCard extends StatelessWidget {
  final SupplierModel supplier;
  final String companyId;

  const _DirectorySupplierCard({
    required this.supplier,
    required this.companyId,
  });

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CeoViewModel>();
    final status = vm.linkStatusFor(supplier.id);
    final isPartner = status == 'Already Partners';
    final isVerified = supplier.isVerified;

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
                    supplier.name.isNotEmpty
                        ? supplier.name[0].toUpperCase()
                        : 'S',
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            supplier.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: CeoColors.navy,
                            ),
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: CeoColors.green,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: CeoColors.textGrey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            [
                              if (supplier.city.isNotEmpty) supplier.city,
                              if (supplier.materialType.isNotEmpty)
                                supplier.materialType,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CeoTheme.mutedStyle(size: 12),
                          ),
                        ),
                      ],
                    ),
                    if (supplier.rating > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: CeoColors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            supplier.rating.toStringAsFixed(1),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: CeoColors.navy,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RelationshipBadge(status: status),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          if (isPartner)
            _PartnerActions(
              supplier: supplier,
              companyId: companyId,
            )
          else
            _RelationshipActions(
              supplier: supplier,
              status: status,
            ),
        ],
      ),
    );
  }
}

class _RelationshipBadge extends StatelessWidget {
  final String status;

  const _RelationshipBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = switch (status) {
      'Already Partners' => (
          label: 'Partner',
          color: CeoColors.green,
          icon: Icons.handshake_rounded,
        ),
      'Request Pending' => (
          label: 'Requested',
          color: CeoColors.amber,
          icon: Icons.hourglass_bottom_rounded,
        ),
      'Request Rejected' => (
          label: 'Rejected',
          color: CeoColors.red,
          icon: Icons.cancel_rounded,
        ),
      _ => (
          label: 'Available',
          color: CeoColors.navy,
          icon: Icons.storefront_outlined,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 14, color: config.color),
          const SizedBox(width: 6),
          Text(
            config.label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: config.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RelationshipActions extends StatelessWidget {
  final SupplierModel supplier;
  final String status;

  const _RelationshipActions({
    required this.supplier,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final vm = context.read<CeoViewModel>();

    switch (status) {
      case 'Request Pending':
        return _statusBanner(
          'Partnership request pending',
          CeoColors.amber,
          Icons.hourglass_bottom_rounded,
        );
      case 'Request Rejected':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusBanner(
              'Previous request was rejected',
              CeoColors.red,
              Icons.cancel_rounded,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _showSendRequestSheet(context, vm, supplier),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('RESEND REQUEST'),
              style: CeoTheme.primaryButtonStyle(height: 44),
            ),
          ],
        );
      default:
        return ElevatedButton.icon(
          onPressed: () => _showSendRequestSheet(context, vm, supplier),
          icon: const Icon(Icons.person_add_rounded, size: 18),
          label: const Text('REQUEST PARTNERSHIP'),
          style: CeoTheme.primaryButtonStyle(height: 44),
        );
    }
  }

  Widget _statusBanner(String label, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSendRequestSheet(
    BuildContext context,
    CeoViewModel ceoVM,
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
      builder: (ctx) => Padding(
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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CeoColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.handshake_outlined,
                  color: CeoColors.navy,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text('Invite Partner', style: CeoTheme.titleStyle(size: 20)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Connect with ${supplier.name} to see their material pricing and start placing orders.',
              style: CeoTheme.mutedStyle(size: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: messageController,
              maxLines: 4,
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
              decoration: CeoTheme.inputDecoration(
                labelText: 'Add an optional message',
                hintText: 'Introduce your company...',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await ceoVM.sendPartnershipRequest(
                  supplier.id,
                  message: messageController.text.trim().isEmpty
                      ? null
                      : messageController.text.trim(),
                );
                if (!context.mounted) return;
                final error = ceoVM.errorMessage;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    backgroundColor:
                        error == null ? CeoColors.green : CeoColors.red,
                    content: Text(
                      error ?? 'Request sent to ${supplier.name}',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text('SEND REQUEST'),
              style: CeoTheme.primaryButtonStyle(height: 52),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerActions extends StatelessWidget {
  final SupplierModel supplier;
  final String companyId;

  const _PartnerActions({
    required this.supplier,
    required this.companyId,
  });

  @override
  Widget build(BuildContext context) {
    final vm = context.read<CeoViewModel>();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _actionButton(
          onPressed: () => _confirmToggle(
            context,
            vm,
            supplier.id,
            companyId,
            activate: false,
          ),
          icon: Icons.block_rounded,
          label: 'Deactivate',
          color: CeoColors.darkAmber,
          isOutlined: true,
        ),
        _actionButton(
          onPressed: () => _showProfileSheet(context, supplier, companyId),
          icon: Icons.analytics_outlined,
          label: 'Performance',
          color: CeoColors.navy,
          isOutlined: true,
        ),
        _actionButton(
          onPressed: () =>
              _confirmRemove(context, vm, supplier.id, supplier.name),
          icon: Icons.link_off_rounded,
          label: 'Remove',
          color: CeoColors.red,
          isOutlined: true,
        ),
      ],
    );
  }

  Widget _actionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required bool isOutlined,
  }) {
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _confirmToggle(
    BuildContext context,
    CeoViewModel vm,
    String supplierId,
    String companyId, {
    required bool activate,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              activate ? Icons.bolt_rounded : Icons.block_rounded,
              color: activate ? CeoColors.green : CeoColors.amber,
            ),
            const SizedBox(width: 10),
            Text(activate ? 'Reactivate Supplier?' : 'Deactivate Supplier?'),
          ],
        ),
        content: Text(
          activate
              ? 'This supplier will regain access to your material inventory and can receive orders.'
              : 'This supplier will no longer receive new orders. Existing orders are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: activate
                ? CeoTheme.primaryButtonStyle(height: 40)
                : ElevatedButton.styleFrom(
                    backgroundColor: CeoColors.darkAmber,
                    foregroundColor: Colors.white,
                  ),
            onPressed: () {
              Navigator.pop(ctx);
              vm.toggleSupplierStatus(supplierId, companyId, activate);
            },
            child: Text(activate ? 'ACTIVATE' : 'DEACTIVATE'),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(
    BuildContext context,
    CeoViewModel vm,
    String supplierId,
    String name,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: CeoColors.red),
            SizedBox(width: 10),
            Text('Remove Partnership?'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove $name? This will break the link, and their materials will be hidden from your field engineers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          OutlinedButton.icon(
            style: CeoTheme.destructiveButtonStyle(height: 40),
            onPressed: () {
              Navigator.pop(ctx);
              vm.removeSupplier(supplierId);
            },
            icon: const Icon(Icons.link_off_rounded, size: 18),
            label: const Text('REMOVE PERMANENTLY'),
          ),
        ],
      ),
    );
  }

  void _showProfileSheet(
    BuildContext context,
    SupplierModel supplier,
    String companyId,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: CeoColors.screenBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CeoColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.analytics_rounded,
                  color: CeoColors.navy,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text('Partner Insights', style: CeoTheme.titleStyle(size: 20)),
              ],
            ),
            const SizedBox(height: 4),
            Text(supplier.name, style: CeoTheme.mutedStyle(size: 14)),
            const SizedBox(height: 24),
            SupplierPerformanceScorecard(
              supplierId: supplier.id,
              companyId: companyId,
              averageRating: supplier.rating,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: CeoTheme.primaryButtonStyle(height: 52),
              child: const Text('CLOSE'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
