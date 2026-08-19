import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../constants/route_names.dart';
import '../../../models/category_model.dart';
import '../../../models/material_model.dart';
import '../../../services/ai_context_service.dart';
import '../../../services/recently_viewed_service.dart';
import '../../../theme/field_theme.dart';
import '../../../utils/currency_formatter.dart';
import '../../../viewmodels/field_user/field_catalog_viewmodel.dart';
import '../../../viewmodels/field_user/field_session_viewmodel.dart';
import '../widgets/field_material_card.dart';

class FieldMarketplaceView extends StatefulWidget {
  final String? initialCategory;

  const FieldMarketplaceView({super.key, this.initialCategory});

  @override
  State<FieldMarketplaceView> createState() => _FieldMarketplaceViewState();
}

class _FieldMarketplaceViewState extends State<FieldMarketplaceView> {
  bool _initialCategoryApplied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialCategoryApplied) {
      _initialCategoryApplied = true;
      _applyInitialCategory();
    }
  }

  @override
  void didUpdateWidget(FieldMarketplaceView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategory != widget.initialCategory) {
      _applyInitialCategory();
      _load();
    }
  }

  void _applyInitialCategory() {
    final catalog = context.read<FieldCatalogViewModel>();
    final category = widget.initialCategory?.trim();
    if (category != null && category.isNotEmpty) {
      catalog.filterByCategory(category);
    } else {
      catalog.filterByCategory(null);
    }
  }

  Future<void> _load() async {
    final session = context.read<FieldSessionViewModel>();
    final catalog = context.read<FieldCatalogViewModel>();
    final companyId = session.companyId;
    if (companyId == null) return;

    if (!catalog.hasCachedMaterials || catalog.categories.isEmpty) {
      await catalog.loadMarketplace(companyId);
    }
    _applyInitialCategory();
    await catalog.prefetchSupplierRatings();
    if (!mounted) return;
    context.read<AiContextService>().updateContext('marketplace', {
      'screen': 'materials marketplace',
    });
  }

  Future<void> _refresh() async {
    final session = context.read<FieldSessionViewModel>();
    final catalog = context.read<FieldCatalogViewModel>();
    final companyId = session.companyId;
    if (companyId == null) return;
    await catalog.loadMarketplace(companyId);
    _applyInitialCategory();
    await catalog.prefetchSupplierRatings();
  }

  void _openCompare(MaterialModel material) {
    context.read<RecentlyViewedService>().persistView(material.id);
    context.push(
      RouteNames.fieldCompare.replaceFirst(
        ':materialId',
        Uri.encodeComponent(material.name),
      ),
    );
  }

  void _showSortSheet(
    BuildContext context,
    CatalogSortOption current,
    ValueChanged<CatalogSortOption> onSelected,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FieldColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sort by',
                style: FieldTypography.titleMedium.copyWith(
                  color: FieldColors.primaryNavy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...CatalogSortOption.values.map((option) {
                final isSelected = option == current;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.pop(ctx);
                    onSelected(option);
                  },
                  title: Text(
                    option.label,
                    style: FieldTypography.bodyMedium.copyWith(
                      color: isSelected
                          ? FieldColors.primaryNavy
                          : FieldColors.textPrimary,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: FieldColors.accentAmber,
                          size: 22,
                        )
                      : null,
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<FieldCatalogViewModel>();
    final title = widget.initialCategory ?? 'Marketplace';
    final badges = _computeMaterialBadges(catalog.catalogMaterials);

    return Theme(
      data: FieldTheme.theme,
      child: Scaffold(
        backgroundColor: FieldColors.screenBackground,
        appBar: FieldAppBar(title: title),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MarketplaceFilterBar(
              categories: catalog.browseCategories,
              selectedCategory: catalog.categoryFilter,
              onCategorySelected: catalog.filterByCategory,
              onSortTap: () => _showSortSheet(
                context,
                catalog.sortOption,
                catalog.setSortOption,
              ),
            ),
            Expanded(
              child: catalog.errorMessage != null && catalog.materials.isEmpty
                  ? _MarketplaceErrorState(
                      message: catalog.errorMessage!,
                      onRetry: _load,
                    )
                  : catalog.isLoading && catalog.materials.isEmpty
                      ? const _MarketplaceGridSkeleton()
                      : catalog.materials.isEmpty
                          ? _MarketplaceEmptyState(
                              onClearFilters: catalog.clearFilters,
                            )
                          : RefreshIndicator(
                              color: FieldColors.primaryNavy,
                              onRefresh: _refresh,
                              child: GridView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.68,
                                ),
                                itemCount: catalog.materials.length,
                                itemBuilder: (context, index) {
                                  final material = catalog.materials[index];
                                  final materialBadges =
                                      badges[material.id] ??
                                          const _MaterialBadgeFlags();
                                  return _MarketplaceMaterialCard(
                                    material: material,
                                    rating: catalog.supplierRatingFor(
                                      material.supplierId,
                                    ),
                                    isAnomaly: materialBadges.isAnomaly,
                                    isBestValue: materialBadges.isBestValue,
                                    onCompare: () => _openCompare(material),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialBadgeFlags {
  final bool isAnomaly;
  final bool isBestValue;

  const _MaterialBadgeFlags({
    this.isAnomaly = false,
    this.isBestValue = false,
  });
}

Map<String, _MaterialBadgeFlags> _computeMaterialBadges(
  List<MaterialModel> allMaterials,
) {
  final byName = <String, List<MaterialModel>>{};
  for (final material in allMaterials) {
    final key = material.name.trim().toLowerCase();
    if (key.isEmpty) continue;
    byName.putIfAbsent(key, () => []).add(material);
  }

  final result = <String, _MaterialBadgeFlags>{};
  for (final group in byName.values) {
    if (group.length < 2) {
      for (final material in group) {
        result[material.id] = const _MaterialBadgeFlags();
      }
      continue;
    }

    final avgPrice = group
            .map((m) => m.pricePerUnit)
            .reduce((a, b) => a + b) /
        group.length;

    final flagged = group
        .map(
          (m) => (
            material: m,
            isAnomaly: m.pricePerUnit > avgPrice * 1.15,
          ),
        )
        .toList();

    final nonAnomalous =
        flagged.where((entry) => !entry.isAnomaly).toList();
    MaterialModel? best;
    if (nonAnomalous.isNotEmpty) {
      nonAnomalous.sort(
        (a, b) =>
            a.material.pricePerUnit.compareTo(b.material.pricePerUnit),
      );
      best = nonAnomalous.first.material;
    }

    for (final entry in flagged) {
      result[entry.material.id] = _MaterialBadgeFlags(
        isAnomaly: entry.isAnomaly,
        isBestValue: best != null &&
            entry.material.id == best.id &&
            !entry.isAnomaly,
      );
    }
  }
  return result;
}

// ─── Sticky filter bar ───────────────────────────────────────────────────────

class _MarketplaceFilterBar extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onCategorySelected;
  final VoidCallback onSortTap;

  const _MarketplaceFilterBar({
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onSortTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: FieldColors.accentAmber, width: 2),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _FilterChip(
                      label: 'All',
                      isSelected: selectedCategory == null,
                      onTap: () => onCategorySelected(null),
                    );
                  }
                  final category = categories[index - 1];
                  return _FilterChip(
                    label: category.name,
                    isSelected: selectedCategory?.toLowerCase() ==
                        category.name.toLowerCase(),
                    onTap: () => onCategorySelected(category.name),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSortTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.swap_vert_rounded,
                      size: 18,
                      color: FieldColors.primaryNavy,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sort',
                      style: FieldTypography.bodyMedium.copyWith(
                        color: FieldColors.primaryNavy,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            color: isSelected ? FieldColors.accentAmber : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? FieldColors.accentAmber
                  : FieldColors.borderSubtle,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: FieldTypography.bodyMedium.copyWith(
              color: isSelected
                  ? FieldColors.primaryNavy
                  : FieldColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Material card ───────────────────────────────────────────────────────────

class _MarketplaceMaterialCard extends StatelessWidget {
  final MaterialModel material;
  final double rating;
  final bool isAnomaly;
  final bool isBestValue;
  final VoidCallback onCompare;

  const _MarketplaceMaterialCard({
    required this.material,
    required this.rating,
    required this.isAnomaly,
    required this.isBestValue,
    required this.onCompare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FieldColors.borderSubtle,
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 110,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _MaterialImageArea(material: material),
                if (isBestValue)
                  const Positioned(
                    top: 6,
                    left: 6,
                    child: _CardBadge(
                      label: 'Best',
                      background: FieldColors.statusSuccess,
                    ),
                  ),
                if (isAnomaly)
                  const Positioned(
                    top: 6,
                    right: 6,
                    child: _CardBadge(
                      label: '⚠',
                      background: FieldColors.statusDanger,
                      compact: true,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FieldTypography.titleMedium.copyWith(
                      fontSize: 13,
                      height: 1.15,
                      color: FieldColors.primaryNavy,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (material.brand?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      material.brand!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FieldTypography.bodyMedium.copyWith(
                        fontSize: 10,
                        color: FieldColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    material.supplierName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FieldTypography.bodyMedium.copyWith(
                      fontSize: 11,
                      color: FieldColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          CurrencyFormatter.formatPKR(material.pricePerUnit),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FieldTypography.titleMedium.copyWith(
                            color: FieldColors.accentAmber,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        '/${material.unit}',
                        style: FieldTypography.bodyMedium.copyWith(
                          fontSize: 11,
                          color: FieldColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (material.bulkDiscountAvailable == true) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: FieldColors.statusSuccess.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Bulk Discount Available',
                        style: FieldTypography.labelSmall.copyWith(
                          color: FieldColors.statusSuccess,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _RatingStars(rating: rating)),
                      const SizedBox(width: 6),
                      SizedBox(
                        height: 30,
                        child: FilledButton(
                          onPressed: onCompare,
                          style: FilledButton.styleFrom(
                            backgroundColor: FieldColors.accentAmber,
                            foregroundColor: FieldColors.primaryNavy,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Compare'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialImageArea extends StatelessWidget {
  final MaterialModel material;

  const _MaterialImageArea({required this.material});

  @override
  Widget build(BuildContext context) {
    final url = material.profileImageUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      color: FieldColors.accentAmber.withValues(alpha: 0.12),
      child: Center(
        child: Icon(
          fieldMaterialCategoryIcon(material.category),
          size: 36,
          color: FieldColors.primaryNavy,
        ),
      ),
    );
  }
}

class _CardBadge extends StatelessWidget {
  final String label;
  final Color background;
  final bool compact;

  const _CardBadge({
    required this.label,
    required this.background,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 11 : 10,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  final double rating;

  const _RatingStars({required this.rating});

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) {
      return Text(
        'No ratings',
        style: FieldTypography.labelSmall.copyWith(
          fontSize: 10,
          color: FieldColors.textMuted,
        ),
      );
    }

    final fullStars = rating.floor().clamp(0, 5);
    final hasHalf = (rating - fullStars) >= 0.25 && fullStars < 5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(fullStars, (_) => const _StarIcon(filled: true)),
        if (hasHalf) const _StarIcon(filled: false, half: true),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: FieldTypography.labelSmall.copyWith(
            fontSize: 11,
            color: FieldColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StarIcon extends StatelessWidget {
  final bool filled;
  final bool half;

  const _StarIcon({required this.filled, this.half = false});

  @override
  Widget build(BuildContext context) {
    return Icon(
      half
          ? Icons.star_half_rounded
          : filled
              ? Icons.star_rounded
              : Icons.star_outline_rounded,
      size: 11,
      color: FieldColors.accentAmber,
    );
  }
}

// ─── Skeleton, empty, error ──────────────────────────────────────────────────

class _MarketplaceGridSkeleton extends StatelessWidget {
  const _MarketplaceGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: FieldColors.borderSubtle,
        highlightColor: FieldColors.surfaceWhite,
        child: Container(
          decoration: BoxDecoration(
            color: FieldColors.borderSubtle,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 110,
                color: FieldColors.borderSubtle,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: double.infinity,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 6),
                      Container(height: 10, width: 80, color: Colors.white),
                      const Spacer(),
                      Container(height: 14, width: 90, color: Colors.white),
                      const SizedBox(height: 8),
                      Container(height: 30, width: double.infinity, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketplaceErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _MarketplaceErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FieldSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 40,
              color: FieldColors.statusDanger,
            ),
            const SizedBox(height: FieldSpacing.md),
            Text(
              'Could not load marketplace',
              style: FieldTypography.titleMedium,
            ),
            const SizedBox(height: FieldSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: FieldTypography.bodyMedium,
            ),
            const SizedBox(height: FieldSpacing.lg),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceEmptyState extends StatelessWidget {
  final VoidCallback onClearFilters;

  const _MarketplaceEmptyState({required this.onClearFilters});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FieldSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_outlined,
              size: 64,
              color: FieldColors.textMuted.withValues(alpha: 0.7),
            ),
            const SizedBox(height: FieldSpacing.md),
            Text(
              'No materials found',
              style: FieldTypography.titleMedium.copyWith(
                color: FieldColors.primaryNavy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: FieldSpacing.sm),
            Text(
              'Try a different category or check back later',
              textAlign: TextAlign.center,
              style: FieldTypography.bodyMedium.copyWith(
                color: FieldColors.textSecondary,
              ),
            ),
            const SizedBox(height: FieldSpacing.lg),
            FilledButton(
              onPressed: onClearFilters,
              style: FilledButton.styleFrom(
                backgroundColor: FieldColors.accentAmber,
                foregroundColor: FieldColors.primaryNavy,
              ),
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }
}
