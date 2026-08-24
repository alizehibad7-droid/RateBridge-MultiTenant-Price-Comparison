// MVVM: View — no business logic

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../theme/ceo_theme.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/ceo_nav_bar.dart';
import '../../widgets/ceo/ceo_widgets.dart';
import '../../widgets/supplier_performance_scorecard.dart';

const _citiesAll = [
  'All',
  'Rawalpindi',
  'Islamabad',
  'Lahore',
  'Karachi',
  'Peshawar'
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
    _cityTabController =
        TabController(length: _citiesAll.length, vsync: this);
  }

  @override
  void dispose() {
    _cityTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterByCity(
      List<Map<String, dynamic>> all, String selectedCity) {
    var result = all;
    
    // 1. Filter by City (only if not 'All')
    // Correct Logic: Only connected suppliers (already in 'all' list) 
    // are filtered by their existing city field.
    if (selectedCity != 'All') {
      result = result.where((s) {
        final supplierCity = (s['city'] ?? '').toString().trim().toLowerCase();
        final targetCity = selectedCity.trim().toLowerCase();
        return supplierCity == targetCity;
      }).toList();
    }
    
    // 2. Filter by Search Query
    if (_searchQuery.isNotEmpty) {
      result = result
          .where((s) => (s['name'] ?? '')
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()))
          .toList();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final companyId =
        context.read<AuthViewModel>().user?.companyId ?? '';

    return Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: CeoAppBar(
        title: 'My Suppliers',
        bottom: TabBar(
          controller: _cityTabController,
          isScrollable: true,
          tabs: _citiesAll.map((c) => Tab(text: c)).toList(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: CeoTheme.inputDecoration(
                hintText: 'Search suppliers...',
                prefixIcon: const Icon(Icons.search, color: CeoColors.textGrey),
              ),
            ),
          ),
          Expanded(
            child: Consumer<CeoViewModel>(
              builder: (context, vm, _) {
                return StreamBuilder<List<Map<String, dynamic>>>(
                  stream: vm.watchMySuppliers(companyId),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final allConnectedSuppliers = snap.data ?? [];

                    return TabBarView(
                      controller: _cityTabController,
                      children: _citiesAll.map((city) {
                        final suppliers = _filterByCity(allConnectedSuppliers, city);
                        if (suppliers.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.store_outlined,
                                    size: 40, color: CeoColors.textGrey),
                                const SizedBox(height: 12),
                                Text(
                                  city == 'All'
                                      ? 'No suppliers linked yet'
                                      : 'No suppliers in $city',
                                  style: CeoTheme.mutedStyle(),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: suppliers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) => _supplierCard(
                              context, vm, suppliers[i], companyId),
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CeoNavBar(currentIndex: 1),
    );
  }

  Widget _supplierCard(BuildContext context, CeoViewModel vm,
      Map<String, dynamic> supplier, String companyId) {
    final supplierId = supplier['id'] as String? ?? '';
    final name = supplier['name'] as String? ?? 'Supplier';
    final city = supplier['city'] as String? ?? '';
    final materialType = supplier['materialType'] as String? ?? '';
    final status = supplier['status'] as String? ?? 'active';
    final isActive = status == 'active';
    final linkedAt = supplier['linkedAt'];

    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isActive
                    ? CeoColors.navy.withValues(alpha: 0.12)
                    : CeoColors.red.withValues(alpha: 0.12),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                  style: GoogleFonts.plusJakartaSans(
                    color: isActive ? CeoColors.navy : CeoColors.red,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: CeoColors.navy,
                      ),
                    ),
                    Text('$city · $materialType',
                        style: CeoTheme.mutedStyle(size: 12)),
                    if (linkedAt != null)
                      Text(
                        'Linked: ${_formatTimestamp(linkedAt)}',
                        style: CeoTheme.mutedStyle(size: 11),
                      ),
                  ],
                ),
              ),
              CeoStatusBadge(
                  status: isActive ? 'active' : 'deactivated'),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              isActive
                  ? OutlinedButton.icon(
                      onPressed: () => _confirmToggle(
                          context, vm, supplierId, companyId,
                          activate: false),
                      icon: const Icon(Icons.block, size: 16),
                      label: const Text('Deactivate'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CeoColors.darkAmber,
                        side: const BorderSide(color: CeoColors.darkAmber),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: () => _confirmToggle(
                          context, vm, supplierId, companyId,
                          activate: true),
                      icon: const Icon(Icons.check_circle_outline,
                          size: 16),
                      label: const Text('Activate'),
                      style: CeoTheme.primaryButtonStyle(height: 40),
                    ),
              OutlinedButton.icon(
                onPressed: () => _showProfileSheet(context, supplier),
                icon: const Icon(Icons.person_outline, size: 16),
                label: const Text('Profile'),
                style: CeoTheme.secondaryButtonStyle(height: 40),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _confirmRemove(context, vm, supplierId, name),
                icon: const Icon(Icons.link_off, size: 16),
                label: const Text('Remove'),
                style: CeoTheme.destructiveButtonStyle(height: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmToggle(BuildContext context, CeoViewModel vm, String supplierId,
      String companyId,
      {required bool activate}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(activate ? 'Activate supplier?' : 'Deactivate supplier?'),
        content: Text(
          activate
              ? 'This supplier will be able to receive orders again.'
              : 'This supplier will no longer receive new orders from your company.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
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
            child: Text(activate ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );
  }

  void _confirmRemove(
      BuildContext context, CeoViewModel vm, String supplierId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove partnership?'),
        content: const Text(
          'Are you sure? This supplier\'s materials will no longer be visible to your field team.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          OutlinedButton(
            style: CeoTheme.destructiveButtonStyle(height: 40),
            onPressed: () {
              Navigator.pop(ctx);
              vm.removeSupplier(supplierId);
            },
            child: const Text('Remove Partnership'),
          ),
        ],
      ),
    );
  }

  void _showProfileSheet(
      BuildContext context, Map<String, dynamic> supplier) {
    final companyId = context.read<AuthViewModel>().user?.companyId ?? '';
    final rating = (supplier['rating'] as num? ?? 0.0).toDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: CeoColors.screenBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: CeoColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(supplier['name'] ?? 'Supplier',
                style: CeoTheme.titleStyle(size: 18)),
            const SizedBox(height: 12),
            SupplierPerformanceScorecard(
              supplierId: supplier['id'] ?? '',
              companyId: companyId,
              averageRating: rating,
            ),
            const SizedBox(height: 20),
            _profileRow(Icons.location_city_outlined,
                supplier['city'] ?? '—'),
            _profileRow(Icons.category_outlined,
                supplier['materialType'] ?? '—'),
            _profileRow(Icons.info_outline,
                'Status: ${supplier['status'] ?? '—'}'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _profileRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: CeoColors.textGrey),
          const SizedBox(width: 10),
          Text(text, style: CeoTheme.bodyStyle()),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic ts) {
    try {
      final date = ts.toDate() as DateTime;
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '—';
    }
  }
}
