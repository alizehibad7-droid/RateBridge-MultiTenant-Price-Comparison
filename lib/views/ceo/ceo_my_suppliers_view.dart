// MVVM: View — no business logic

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/app_theme.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/ceo_nav_bar.dart';
import '../../constants/app_colors.dart';

const _citiesAll = ['All', 'Rawalpindi', 'Islamabad', 'Lahore', 'Karachi', 'Peshawar'];

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
      List<Map<String, dynamic>> all, String city) {
    var result = all;
    if (city != 'All') {
      result =
          result.where((s) => (s['city'] ?? '') == city).toList();
    }
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Suppliers'),
        bottom: TabBar(
          controller: _cityTabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
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
              decoration: const InputDecoration(
                hintText: 'Search suppliers...',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
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
                    final all = snap.data ?? [];

                    return TabBarView(
                      controller: _cityTabController,
                      children: _citiesAll.map((city) {
                        final suppliers = _filterByCity(all, city);
                        if (suppliers.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.store_outlined,
                                    size: 40, color: AppColors.textMuted),
                                const SizedBox(height: 12),
                                Text(
                                  city == 'All'
                                      ? 'No suppliers linked yet'
                                      : 'No suppliers in $city',
                                  style: AppTextStyles.bodyMuted,
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
                          itemBuilder: (context, i) =>
                              _supplierCard(context, vm, suppliers[i], companyId),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: appCardDecoration().copyWith(
        border: Border.all(
          color: isActive ? AppColors.border : AppColors.danger.withOpacity(0.3),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor:
                    isActive ? AppColors.infoBg : AppColors.dangerBg,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                  style: TextStyle(
                      color: isActive ? AppColors.primary : AppColors.danger,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    Text('$city · $materialType',
                        style: AppTextStyles.bodyMuted),
                    if (linkedAt != null)
                      Text(
                        'Linked: ${_formatTimestamp(linkedAt)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
              _statusBadge(status),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              // Activate / Deactivate toggle
              Expanded(
                child: isActive
                    ? OutlinedButton.icon(
                        onPressed: () => _confirmToggle(
                            context, vm, supplierId, companyId,
                            activate: false),
                        icon: const Icon(Icons.block, size: 16),
                        label: const Text('Deactivate'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.warning,
                            side: const BorderSide(
                                color: AppColors.warning)),
                      )
                    : ElevatedButton.icon(
                        onPressed: () => _confirmToggle(
                            context, vm, supplierId, companyId,
                            activate: true),
                        icon: const Icon(Icons.check_circle_outline,
                            size: 16),
                        label: const Text('Activate',
                            style: AppTextStyles.button),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success),
                      ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    _showProfileSheet(context, supplier),
                icon: const Icon(Icons.person_outline, size: 16),
                label: const Text('Profile'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    _confirmRemove(context, vm, supplierId, name),
                icon: const Icon(Icons.link_off, size: 16),
                label: const Text('Remove'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger)),
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
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  activate ? AppColors.success : AppColors.warning,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              vm.toggleSupplierStatus(supplierId, companyId, activate);
            },
            child: Text(activate ? 'Activate' : 'Deactivate',
                style: AppTextStyles.button),
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
        title: const Text('Remove supplier?'),
        content: Text(
          'This will permanently unlink $name from your company. '
          'They can request to join again later.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              vm.removeSupplier(supplierId);
            },
            child: const Text('Remove', style: AppTextStyles.button),
          ),
        ],
      ),
    );
  }

  void _showProfileSheet(
      BuildContext context, Map<String, dynamic> supplier) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
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
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(supplier['name'] ?? 'Supplier',
                style: AppTextStyles.h2),
            const SizedBox(height: 12),
            _profileRow(Icons.location_city_outlined,
                supplier['city'] ?? '—'),
            _profileRow(Icons.category_outlined,
                supplier['materialType'] ?? '—'),
            _profileRow(Icons.info_outline,
                'Status: ${supplier['status'] ?? '—'}'),
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
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Text(text, style: AppTextStyles.body),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? AppColors.successBg : AppColors.dangerBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        isActive ? 'Active' : 'Deactivated',
        style: TextStyle(
            color: isActive ? AppColors.success : AppColors.danger,
            fontSize: 11,
            fontWeight: FontWeight.w600),
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
