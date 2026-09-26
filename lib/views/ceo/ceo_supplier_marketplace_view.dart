// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/supplier_model.dart';
import '../../theme/ceo_theme.dart';
import '../../widgets/ceo/ceo_widgets.dart';
import 'dart:async';

class CeoSupplierMarketplaceView extends StatefulWidget {
  final bool isTab;

  const CeoSupplierMarketplaceView({super.key, this.isTab = false});

  @override
  State<CeoSupplierMarketplaceView> createState() =>
      _CeoSupplierMarketplaceViewState();
}

class _CeoSupplierMarketplaceViewState
    extends State<CeoSupplierMarketplaceView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _selectedCity = 'All';
  String _selectedCategory = 'All';
  bool _verifiedOnly = false;
  String _sortBy = 'Rating';

  final List<String> _cities = [
    'All',
    'Rawalpindi',
    'Islamabad',
    'Lahore',
    'Karachi',
    'Peshawar',
    'Multan',
  ];

  final List<String> _categories = [
    'All',
    'Cement',
    'Steel',
    'Bricks',
    'Sand',
    'Electrical',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<CeoViewModel>();
      final companyId = vm.company?.id;
      if (companyId != null && companyId.isNotEmpty) {
        vm.ensurePartnershipStatusWatch(companyId);
      }
      vm.loadMarketplace();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      context.read<CeoViewModel>().searchSuppliers(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ceoVM = context.read<CeoViewModel>();
    final companyId = context.read<AuthViewModel>().user?.companyId ?? '';

    return Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: widget.isTab
          ? null
          : const CeoAppBar(title: 'Supplier Marketplace'),
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
              onChanged: _onSearchChanged,
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
              decoration: CeoTheme.inputDecoration(
                hintText: 'Search top suppliers...',
                prefixIcon: const Icon(Icons.search_rounded, color: CeoColors.navy, size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel_rounded, size: 20, color: CeoColors.textGrey),
                        onPressed: () {
                          _searchController.clear();
                          ceoVM.loadMarketplace();
                        },
                      )
                    : null,
              ),
            ),
          ),
          Container(
            height: 56,
            color: Colors.white,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  avatar: Icon(
                    _verifiedOnly ? Icons.verified_rounded : Icons.verified_outlined,
                    size: 16,
                    color: _verifiedOnly ? CeoColors.navy : CeoColors.textGrey,
                  ),
                  label: Text('Verified only', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: _verifiedOnly ? FontWeight.w700 : FontWeight.w500)),
                  selected: _verifiedOnly,
                  onSelected: (v) {
                    setState(() => _verifiedOnly = v);
                    ceoVM.applyFilters(
                      city: _selectedCity,
                      category: _selectedCategory,
                      verifiedOnly: v,
                    );
                  },
                  backgroundColor: CeoColors.screenBg,
                  selectedColor: CeoColors.navy.withValues(alpha: 0.1),
                  checkmarkColor: CeoColors.navy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(color: _verifiedOnly ? CeoColors.navy : CeoColors.border),
                ),
                const SizedBox(width: 10),
                _dropdownChip(
                  icon: Icons.location_on_outlined,
                  label: _selectedCity == 'All' ? 'City' : _selectedCity,
                  items: _cities,
                  isActive: _selectedCity != 'All',
                  onSelected: (val) {
                    setState(() => _selectedCity = val);
                    ceoVM.applyFilters(
                      city: val,
                      category: _selectedCategory,
                      verifiedOnly: _verifiedOnly,
                    );
                  },
                ),
                const SizedBox(width: 10),
                _dropdownChip(
                  icon: Icons.category_outlined,
                  label: _selectedCategory == 'All' ? 'Category' : _selectedCategory,
                  items: _categories,
                  isActive: _selectedCategory != 'All',
                  onSelected: (val) {
                    setState(() => _selectedCategory = val);
                    ceoVM.applyFilters(
                      city: _selectedCity,
                      category: val,
                      verifiedOnly: _verifiedOnly,
                    );
                  },
                ),
                const SizedBox(width: 10),
                _dropdownChip(
                  icon: Icons.sort_rounded,
                  label: 'Sort: $_sortBy',
                  items: const ['Rating', 'Name'],
                  isActive: true,
                  onSelected: (val) {
                    setState(() => _sortBy = val);
                    ceoVM.sortSuppliers(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Consumer<CeoViewModel>(
              builder: (context, vm, _) {
                if (vm.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (vm.marketplaceSuppliers.isEmpty) {
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
                          child: const Icon(Icons.storefront_rounded, size: 64, color: CeoColors.textGrey),
                        ),
                        const SizedBox(height: 24),
                        Text('No suppliers found', style: CeoTheme.titleStyle(size: 18).copyWith(color: CeoColors.textGrey)),
                        const SizedBox(height: 8),
                        Text('Try clearing filters or searching differently', style: CeoTheme.mutedStyle()),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: vm.marketplaceSuppliers.length,
                  itemBuilder: (context, index) {
                    final supplier = vm.marketplaceSuppliers[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SupplierMarketCard(
                        supplier: supplier,
                        companyId: companyId,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdownChip({
    required IconData icon,
    required String label,
    required List<String> items,
    required bool isActive,
    required ValueChanged<String> onSelected,
  }) {
    return GestureDetector(
      onTap: () async {
        final val = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: CeoColors.border, borderRadius: BorderRadius.circular(2))),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: items
                        .map((item) => ListTile(
                              leading: Icon(icon, size: 18, color: label == item ? CeoColors.amber : CeoColors.textGrey),
                              title: Text(item,
                                  style: GoogleFonts.plusJakartaSans(
                                      fontWeight: label == item ? FontWeight.bold : FontWeight.normal,
                                      color: CeoColors.navy)),
                              trailing: label == item ? const Icon(Icons.check_circle_rounded, color: CeoColors.amber, size: 18) : null,
                              onTap: () => Navigator.pop(context, item),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        );
        if (val != null) onSelected(val);
      },
      child: Chip(
        avatar: Icon(icon, size: 14, color: isActive ? CeoColors.navy : CeoColors.textGrey),
        label: Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.w500, color: isActive ? CeoColors.navy : CeoColors.textGrey)),
        deleteIcon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
        onDeleted: () {}, // Triggered by tapping the chip itself in our GestureDetector
        backgroundColor: isActive ? CeoColors.navy.withValues(alpha: 0.05) : CeoColors.screenBg,
        side: BorderSide(color: isActive ? CeoColors.navy : CeoColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _SupplierMarketCard extends StatelessWidget {
  final SupplierModel supplier;
  final String companyId;

  const _SupplierMarketCard({
    required this.supplier,
    required this.companyId,
  });

  @override
  Widget build(BuildContext context) {
    final ceoVM = context.watch<CeoViewModel>();
    final invStatus = ceoVM.linkStatusFor(supplier.id);
    final isVerified = supplier.isVerified;
    final rating = supplier.rating;
    final contracts = supplier.activeContracts;
    final category = supplier.materialType;

    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: CeoColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    supplier.name.isNotEmpty
                        ? supplier.name.substring(0, 1).toUpperCase()
                        : 'S',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      color: CeoColors.navy,
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, color: CeoColors.green, size: 18),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: CeoColors.textGrey),
                        const SizedBox(width: 4),
                        Text(supplier.city, style: CeoTheme.mutedStyle(size: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (category.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: CeoColors.navy.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: CeoColors.navy.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.category_outlined, size: 12, color: CeoColors.navy),
                      const SizedBox(width: 6),
                      Text(
                        category,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: CeoColors.navy,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 18, color: CeoColors.amber),
                  const SizedBox(width: 4),
                  Text(
                    rating.toStringAsFixed(1),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: CeoColors.navy,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('($contracts)', style: CeoTheme.mutedStyle(size: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildActionButton(context, ceoVM, invStatus, supplier),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    CeoViewModel ceoVM,
    String invStatus,
    SupplierModel supplier,
  ) {
    switch (invStatus) {
      case 'Not Invited':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _showSendRequestSheet(context, ceoVM, supplier),
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('REQUEST PARTNERSHIP'),
            style: CeoTheme.primaryButtonStyle(height: 48),
          ),
        );

      case 'Request Pending':
        return _statusIndicator(
          'Awaiting Response',
          CeoColors.amber,
          Icons.hourglass_bottom_rounded,
        );

      case 'Already Partners':
        return _statusIndicator(
          'Linked Partner',
          CeoColors.green,
          Icons.handshake_rounded,
        );

      case 'Request Rejected':
        return Column(
          children: [
            _statusIndicator(
              'Request Rejected',
              CeoColors.red,
              Icons.cancel_rounded,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showSendRequestSheet(context, ceoVM, supplier),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('RESEND REQUEST'),
                style: CeoTheme.secondaryButtonStyle(height: 40),
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _statusIndicator(String label, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
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
          Text(
            label.toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 0.5,
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
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: CeoColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.handshake_outlined, color: CeoColors.navy, size: 24),
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
                      backgroundColor: CeoColors.green,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.send_rounded),
              label: const Text('SEND REQUEST'),
              style: CeoTheme.primaryButtonStyle(height: 52),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
