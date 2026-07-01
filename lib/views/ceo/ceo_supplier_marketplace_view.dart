// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/supplier_model.dart';
import '../../constants/app_colors.dart';
import 'dart:async';

class CeoSupplierMarketplaceView extends StatefulWidget {
  final bool isTab; // true when embedded in dashboard bottom nav tab

  const CeoSupplierMarketplaceView({super.key, this.isTab = false});

  @override
  State<CeoSupplierMarketplaceView> createState() =>
      _CeoSupplierMarketplaceViewState();
}

class _CeoSupplierMarketplaceViewState
    extends State<CeoSupplierMarketplaceView> {

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _selectedCity     = 'All';
  String _selectedCategory = 'All';
  bool   _verifiedOnly     = false;
  String _sortBy           = 'Rating';

  final List<String> _cities = [
    'All', 'Rawalpindi', 'Islamabad', 'Lahore',
    'Karachi', 'Peshawar', 'Multan',
  ];

  final List<String> _categories = [
    'All', 'Cement', 'Steel', 'Bricks', 'Sand', 'Electrical',
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
    final ceoVM    = context.read<CeoViewModel>();
    final companyId = context.read<AuthViewModel>().user?.companyId ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.isTab ? null : AppBar(
        title: const Text(
          'Supplier Marketplace',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search suppliers...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    ceoVM.loadMarketplace();
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Filter chips
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              children: [
                // Verified toggle
                FilterChip(
                  label: const Text('Verified only'),
                  selected: _verifiedOnly,
                  onSelected: (v) {
                    setState(() => _verifiedOnly = v);
                    ceoVM.applyFilters(
                      city:         _selectedCity,
                      category:     _selectedCategory,
                      verifiedOnly: v,
                    );
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                ),
                const SizedBox(width: 8),

                // City filter
                _dropdownChip(
                  label: 'City: $_selectedCity',
                  items: _cities,
                  onSelected: (val) {
                    setState(() => _selectedCity = val);
                    ceoVM.applyFilters(
                      city:         val,
                      category:     _selectedCategory,
                      verifiedOnly: _verifiedOnly,
                    );
                  },
                ),
                const SizedBox(width: 8),

                // Category filter
                _dropdownChip(
                  label: 'Category: $_selectedCategory',
                  items: _categories,
                  onSelected: (val) {
                    setState(() => _selectedCategory = val);
                    ceoVM.applyFilters(
                      city:         _selectedCity,
                      category:     val,
                      verifiedOnly: _verifiedOnly,
                    );
                  },
                ),
                const SizedBox(width: 8),

                // Sort
                _dropdownChip(
                  label: 'Sort: $_sortBy',
                  items: ['Rating', 'Name'],
                  onSelected: (val) {
                    setState(() => _sortBy = val);
                    ceoVM.sortSuppliers(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Supplier list
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
                        Icon(Icons.store_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('No suppliers found',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: vm.marketplaceSuppliers.length,
                  itemBuilder: (context, index) {
                    final supplier = vm.marketplaceSuppliers[index];
                    return _SupplierMarketCard(
                      supplier:  supplier,
                      companyId: companyId,
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
    required String label,
    required List<String> items,
    required ValueChanged<String> onSelected,
  }) {
    return GestureDetector(
      onTap: () async {
        final val = await showModalBottomSheet<String>(
          context: context,
          builder: (_) => ListView(
            shrinkWrap: true,
            children: items.map((item) => ListTile(
              title: Text(item),
              onTap: () => Navigator.pop(context, item),
            )).toList(),
          ),
        );
        if (val != null) onSelected(val);
      },
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        deleteIcon: const Icon(Icons.arrow_drop_down, size: 18),
        onDeleted: () {},
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
        final rating     = supplier.rating;
        final contracts  = supplier.activeContracts;
        final category   = supplier.materialType;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        supplier.name.isNotEmpty ? supplier.name.substring(0, 1).toUpperCase() : 'S',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                supplier.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              if (isVerified) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Verified',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            supplier.city,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Category tag
                if (category.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // Rating + contract count
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.handshake_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '$contracts active contracts',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action Button
                _buildActionButton(context, ceoVM, invStatus, supplier),
              ],
            ),
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
          child: ElevatedButton(
            onPressed: () => _showSendRequestSheet(context, ceoVM, supplier),
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Send Partnership Request'),
          ),
        );

      case 'Request Pending':
        return _statusBadge(
          'Request Pending',
          Colors.amber,
          Icons.schedule,
        );

      case 'Already Partners':
        return _statusBadge(
          'Already Partners',
          Colors.green,
          Icons.check_circle,
        );

      case 'Request Rejected':
        return _statusBadge(
          'Request Rejected',
          Colors.red,
          Icons.cancel_outlined,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _statusBadge(String label, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
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
              'Partnership request',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a request to ${supplier.name}. They must accept before materials appear for your field team.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Optional message',
                hintText: 'Introduce your company or project needs',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
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
                      content: Text('Request sent to ${supplier.name}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }
}
