// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/route_names.dart';
import '../../models/material_model.dart';
import '../../theme/supplier_theme.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../views/field_user/widgets/field_material_card.dart';
import '../../widgets/app_network_image.dart';
import '../../utils/app_navigation.dart';
import '../../widgets/supplier/supplier_async_states.dart';

class SupplierMaterialDetailView extends StatefulWidget {
  final String materialId;
  final MaterialModel? initialMaterial;

  const SupplierMaterialDetailView({
    super.key,
    required this.materialId,
    this.initialMaterial,
  });

  @override
  State<SupplierMaterialDetailView> createState() =>
      _SupplierMaterialDetailViewState();
}

class _SupplierMaterialDetailViewState
    extends State<SupplierMaterialDetailView> {
  MaterialModel? _fetched;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  Future<void> _ensureLoaded() async {
    final vm = context.read<SupplierViewModel>();
    if (vm.materialById(widget.materialId) != null) return;
    if (widget.initialMaterial != null) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final material = await vm.fetchMaterialById(widget.materialId);
      if (!mounted) return;
      setState(() {
        _fetched = material;
        _error = material == null ? 'Material not found' : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  MaterialModel? _resolve(SupplierViewModel vm) {
    return vm.materialById(widget.materialId) ??
        widget.initialMaterial ??
        _fetched;
  }

  (Color bg, Color fg, String label) _stockStyle(String? status) {
    final value = (status ?? 'Available').toLowerCase();
    if (value.contains('out')) {
      return (
        FieldColors.statusDanger.withValues(alpha: 0.12),
        FieldColors.statusDanger,
        'Out of Stock',
      );
    }
    if (value.contains('limited') || value.contains('low')) {
      return (
        FieldColors.accentAmberSoft,
        FieldColors.statusWarning,
        'Limited',
      );
    }
    return (
      FieldColors.statusSuccess.withValues(alpha: 0.12),
      FieldColors.statusSuccess,
      'Available',
    );
  }

  String _display(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? '—' : trimmed;
  }

  String _quantityLabel(MaterialModel material) {
    final qty = material.minOrderQuantity;
    if (qty == null) return 'No minimum';
    final formatted = qty.truncateToDouble() == qty
        ? qty.toStringAsFixed(0)
        : qty.toString();
    final unit = material.unit.trim();
    return unit.isEmpty ? formatted : '$formatted $unit';
  }

  Future<void> _openEdit(MaterialModel material) async {
    final saved = await context.push<bool>(
      RouteNames.supplierEditMaterial.replaceFirst(':matId', material.id),
      extra: material,
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Material updated')),
    );
  }

  Future<void> _confirmDelete(MaterialModel material) async {
    final companyId = context.read<SupplierViewModel>().selectedCompanyId;
    if (companyId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove listing?'),
        content: Text(
          'Remove "${material.name}" from the marketplace? Past orders keep their details. Active orders will block this.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<SupplierViewModel>().deleteMaterial(material.id, companyId);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _openImage(String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenImageView(imageUrl: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SupplierViewModel>();
    final material = _resolve(vm);

    if (_loading && material == null) {
      return const Scaffold(
        backgroundColor: FieldColors.screenBackground,
        appBar: SupplierAppBar(title: 'Material Detail'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (material == null) {
      return Scaffold(
        backgroundColor: FieldColors.screenBackground,
        appBar: const SupplierAppBar(title: 'Material Detail'),
        body: SupplierEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'Material not found',
          subtitle: _error ?? 'This listing may have been removed.',
        ),
      );
    }

    final stock = _stockStyle(material.stockStatus);
    final imageUrl = material.profileImageUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: SupplierAppBar(
        title: 'Material Detail',
        actions: [
          IconButton(
            onPressed: () => _openEdit(material),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit material',
          ),
          IconButton(
            onPressed: () => _confirmDelete(material),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete material',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _confirmDelete(material),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('Delete'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openEdit(material),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  label: const Text('Edit Material'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        children: [
          _ImageHero(
            material: material,
            imageUrl: imageUrl,
            onTap: hasImage ? () => _openImage(imageUrl) : null,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: SupplierTheme.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        material.name,
                        style: AppTextStyles.h2.copyWith(
                          color: FieldColors.primaryNavy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: stock.$1,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        stock.$3,
                        style: AppTextStyles.caption.copyWith(
                          color: stock.$2,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(
                      icon: fieldMaterialCategoryIcon(material.category),
                      label: _display(material.category),
                    ),
                    if (material.isCertified)
                      const _Chip(
                        icon: Icons.verified_outlined,
                        label: 'Certified',
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  CurrencyFormatter.formatPKR(material.pricePerUnit),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: FieldColors.accentAmber,
                  ),
                ),
                Text(
                  'per ${material.unit}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          if (material.description != null &&
              material.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Description',
              child: Text(
                material.description!.trim(),
                style: AppTextStyles.body,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Listing details',
            child: Column(
              children: [
                _DetailRow(label: 'Brand', value: _display(material.brand)),
                _DetailRow(
                  label: 'Grade',
                  value: _display(material.qualityGrade),
                ),
                _DetailRow(label: 'Quantity', value: _quantityLabel(material)),
                _DetailRow(label: 'Unit', value: _display(material.unit)),
                _DetailRow(
                  label: 'Origin city',
                  value: _display(material.originCity),
                ),
                _DetailRow(
                  label: 'Specifications',
                  value: _display(material.specifications),
                ),
                _DetailRow(
                  label: 'Added',
                  value: material.createdAt == null
                      ? '—'
                      : DateFormat('MMM d, yyyy').format(material.createdAt!),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Delivery',
            child: Column(
              children: [
                _DetailRow(
                  label: 'Delivery time',
                  value: _display(material.deliveryTime),
                ),
                _DetailRow(
                  label: 'Coverage',
                  value: _display(material.deliveryCoverageArea),
                ),
                _DetailRow(
                  label: 'Charges',
                  value: _display(material.deliveryCharges),
                ),
              ],
            ),
          ),
          if (material.bulkDiscountAvailable == true) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Bulk discount',
              child: Text(
                _display(material.bulkDiscountDetails),
                style: AppTextStyles.body,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImageHero extends StatelessWidget {
  final MaterialModel material;
  final String? imageUrl;
  final VoidCallback? onTap;

  const _ImageHero({
    required this.material,
    required this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FieldColors.surfaceWhite,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FieldRadius.card),
        side: const BorderSide(color: FieldColors.borderSubtle),
      ),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 220,
          width: double.infinity,
          child: AppNetworkImage(
            url: imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 220,
            debugLabel: 'detail:${material.id}',
            fallback: _Fallback(material: material),
          ),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final MaterialModel material;

  const _Fallback({required this.material});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FieldColors.primaryNavy.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          fieldMaterialCategoryIcon(material.category),
          size: 56,
          color: FieldColors.primaryNavy.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: SupplierTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.h3.copyWith(
              color: FieldColors.primaryNavy,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: AppTextStyles.caption),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: FieldColors.primaryNavy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: FieldColors.primaryNavy),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: FieldColors.primaryNavy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FullScreenImageView extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImageView({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppNavigation.leading(context, color: Colors.white),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          child: AppNetworkImage(
            url: imageUrl,
            fit: BoxFit.contain,
            debugLabel: 'detail-full',
            loading: const Center(child: CircularProgressIndicator()),
            fallback: const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}
