import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../constants/route_names.dart';
import '../../../models/material_listing.dart';
import '../../../services/ai_context_service.dart';
import '../../../services/recently_viewed_service.dart';
import '../../../theme/field_theme.dart';
import '../../../utils/app_navigation.dart';
import '../../../utils/currency_formatter.dart';
import '../../../viewmodels/field_user/field_compare_viewmodel.dart';
import '../../../viewmodels/field_user/field_session_viewmodel.dart';
import '../../../widgets/rating_stars_widget.dart';
import '../chat/field_chat_thread_args.dart';
import '../widgets/field_material_card.dart';

class FieldCompareView extends StatefulWidget {
  final String materialName;

  const FieldCompareView({super.key, required this.materialName});

  @override
  State<FieldCompareView> createState() => _FieldCompareViewState();
}

class _FieldCompareViewState extends State<FieldCompareView> {
  String? _sessionError;
  bool _loadScheduled = false;

  static const _appBarNavy = FieldColors.primaryNavy;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (_loadScheduled) return;
    _loadScheduled = true;

    final session = context.read<FieldSessionViewModel>();
    final companyId = session.companyId;
    if (companyId == null) {
      if (mounted) {
        setState(() => _sessionError = 'Session not ready. Please restart.');
      }
      _loadScheduled = false;
      return;
    }

    final materialName = widget.materialName.trim();
    if (materialName.isEmpty) {
      if (mounted) {
        setState(() => _sessionError = 'Material name missing.');
      }
      _loadScheduled = false;
      return;
    }

    if (mounted && _sessionError != null) {
      setState(() => _sessionError = null);
    }
    await context
        .read<FieldCompareViewModel>()
        .loadComparison(companyId, materialName);

    _loadScheduled = false;

    if (!mounted) return;
    final vm = context.read<FieldCompareViewModel>();
    if (vm.rawResults.isNotEmpty) {
      final pick = vm.bestValueSupplier ?? vm.rawResults.first;
      if (pick.id.isNotEmpty) {
        await context.read<RecentlyViewedService>().persistView(pick.id);
      }
    }
    if (vm.rawResults.isNotEmpty) {
      context.read<AiContextService>().updateContext('compare', {
        'materialName': widget.materialName,
        'supplierCount': vm.rawResults.length,
        'bestSupplier': vm.bestValueSupplier?.supplierName,
        'bestPrice': vm.bestValueSupplier?.pricePerUnit,
        'suppliers': vm.rawResults.map((r) => {
          'name': r.supplierName,
          'price': r.pricePerUnit,
          'rating': r.supplierRating,
        }).toList(),
      });
    }
  }

  Future<void> _refresh() async {
    final companyId = context.read<FieldSessionViewModel>().companyId;
    if (companyId == null) return;
    await context
        .read<FieldCompareViewModel>()
        .loadComparison(companyId, widget.materialName);
  }

  void _openTrends() {
    final vm = context.read<FieldCompareViewModel>();
    if (vm.rawResults.isEmpty) return;
    final pick = vm.bestValueSupplier ?? vm.rawResults.first;
    context.push(
      RouteNames.fieldTrend
          .replaceFirst(':matId', Uri.encodeComponent(pick.id))
          .replaceFirst(':supplierUid', Uri.encodeComponent(pick.supplierId)),
    );
  }

  void _openPlaceOrder(MaterialListing listing) {
    if (listing.id.isNotEmpty) {
      context.read<RecentlyViewedService>().persistView(listing.id);
    }
    context.push(RouteNames.fieldPlaceOrder, extra: listing);
  }

  void _openSupplierProfile(MaterialListing listing) {
    context.push(
      RouteNames.fieldSupplierProfile.replaceFirst(
        ':supplierUid',
        listing.supplierId,
      ),
    );
  }

  void _openChat(MaterialListing listing) {
    context.push(
      RouteNames.fieldChatThread.replaceFirst(':orderId', listing.supplierId),
      extra: FieldChatThreadArgs(
        supplierUid: listing.supplierId,
        supplierName: listing.supplierName,
      ),
    );
  }

  void _openMarketplace() {
    context.push(RouteNames.fieldMarketplace);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<FieldSessionViewModel>();
    final vm = context.watch<FieldCompareViewModel>();

    if (_sessionError != null &&
        session.companyId != null &&
        widget.materialName.trim().isNotEmpty &&
        !_loadScheduled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }

    return Theme(
      data: FieldTheme.theme,
      child: Scaffold(
        backgroundColor: FieldColors.screenBackground,
        appBar: AppBar(
          backgroundColor: _appBarNavy,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: AppNavigation.leading(context, color: Colors.white),
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            widget.materialName,
            style: FieldTypography.titleMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: _sessionError != null
            ? _CompareErrorState(message: _sessionError!, onRetry: _load)
            : vm.isLoading
                ? const _CompareLoadingBody()
                : vm.errorMessage != null
                    ? _CompareErrorState(
                        message: vm.errorMessage!,
                        onRetry: _load,
                      )
                    : vm.rawResults.isEmpty
                        ? _CompareEmptyState(onBrowse: _openMarketplace)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _MaterialSummaryStrip(
                                materialName: widget.materialName,
                                category: vm.rawResults.first.category,
                                supplierCount: vm.rawResults.length,
                              ),
                              _CompareSortRow(
                                sortBy: vm.sortBy,
                                onSortChanged: vm.setSortBy,
                              ),
                              if (vm.availableCities.isNotEmpty)
                                _CityFilterRow(
                                  cities: vm.availableCities,
                                  selectedCity: vm.cityFilter,
                                  onCityChanged: vm.setCityFilter,
                                ),
                              if (vm.isAiLoading ||
                                  (vm.aiSummary != null &&
                                      vm.aiSummary!.isNotEmpty))
                                _CompareAiInsightBanner(
                                  text: vm.isAiLoading
                                      ? 'Comparing suppliers…'
                                      : vm.aiSummary!,
                                ),
                              Expanded(
                                child: vm.results.isEmpty
                                    ? _CompareFilteredEmptyState(
                                        onClearFilter: vm.clearCityFilter,
                                      )
                                    : RefreshIndicator(
                                        color: FieldColors.primaryNavy,
                                        onRefresh: _refresh,
                                        child: ListView(
                                          physics:
                                              const AlwaysScrollableScrollPhysics(
                                            parent: BouncingScrollPhysics(),
                                          ),
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            8,
                                            16,
                                            32,
                                          ),
                                          children: [
                                            ...vm.results.map(
                                              (listing) => Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 12,
                                                ),
                                                child: _SupplierCompareCard(
                                                  listing: listing,
                                                  badge: vm.badgeFor(listing),
                                                  aiInsightLine:
                                                      vm.insightLineFor(listing),
                                                  onOrder: () =>
                                                      _openPlaceOrder(listing),
                                                  onViewProfile: () =>
                                                      _openSupplierProfile(
                                                        listing,
                                                      ),
                                                  onMessage: () =>
                                                      _openChat(listing),
                                                ),
                                              ),
                                            ),
                                            _ViewPriceTrendButton(
                                              onPressed: vm.rawResults.isEmpty
                                                  ? null
                                                  : _openTrends,
                                            ),
                                          ],
                                        ),
                                      ),
                              ),
                            ],
                          ),
      ),
    );
  }
}

class _CompareAiInsightBanner extends StatelessWidget {
  const _CompareAiInsightBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: FieldColors.accentAmber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: const Border(
            left: BorderSide(color: FieldColors.accentAmber, width: 3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.auto_awesome,
              size: 16,
              color: FieldColors.accentAmber,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: FieldTypography.bodyMedium.copyWith(
                  fontSize: 12,
                  color: FieldColors.primaryNavy,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Material summary strip ──────────────────────────────────────────────────

class _MaterialSummaryStrip extends StatelessWidget {
  final String materialName;
  final String category;
  final int supplierCount;

  const _MaterialSummaryStrip({
    required this.materialName,
    required this.category,
    required this.supplierCount,
  });

  @override
  Widget build(BuildContext context) {
    final countLabel =
        '$supplierCount supplier${supplierCount == 1 ? '' : 's'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        elevation: 2,
        shadowColor: FieldColors.primaryNavy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: FieldColors.accentAmber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  fieldMaterialCategoryIcon(category),
                  color: FieldColors.primaryNavy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      materialName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: FieldTypography.titleMedium.copyWith(
                        color: FieldColors.primaryNavy,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category,
                      style: FieldTypography.bodyMedium.copyWith(
                        fontSize: 12,
                        color: FieldColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: FieldColors.accentAmber.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  countLabel,
                  style: FieldTypography.labelSmall.copyWith(
                    color: FieldColors.accentAmber,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
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

// ─── Sort row ────────────────────────────────────────────────────────────────

class _CompareSortRow extends StatelessWidget {
  final CompareSortOption sortBy;
  final ValueChanged<CompareSortOption> onSortChanged;

  const _CompareSortRow({
    required this.sortBy,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _SortSegment(
              label: 'Price ↑',
              isActive: sortBy == CompareSortOption.price,
              onTap: () => onSortChanged(CompareSortOption.price),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SortSegment(
              label: 'Rating ↑',
              isActive: sortBy == CompareSortOption.rating,
              onTap: () => onSortChanged(CompareSortOption.rating),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortSegment extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SortSegment({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: isActive ? FieldColors.accentAmber : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? FieldColors.accentAmber
                  : FieldColors.borderSubtle,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              label,
              style: FieldTypography.bodyMedium.copyWith(
                color: isActive
                    ? FieldColors.primaryNavy
                    : FieldColors.textSecondary,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── City filter (preserves existing filter logic) ───────────────────────────

class _CityFilterRow extends StatelessWidget {
  final List<String> cities;
  final String? selectedCity;
  final ValueChanged<String?> onCityChanged;

  const _CityFilterRow({
    required this.cities,
    required this.selectedCity,
    required this.onCityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        children: [
          _CityChip(
            label: 'All cities',
            isSelected: selectedCity == null,
            onTap: () => onCityChanged(null),
          ),
          ...cities.map(
            (city) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _CityChip(
                label: city,
                isSelected: selectedCity == city,
                onTap: () => onCityChanged(city),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CityChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CityChip({
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
            color: isSelected
                ? FieldColors.primaryNavy.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? FieldColors.primaryNavy.withValues(alpha: 0.35)
                  : FieldColors.borderSubtle,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: FieldTypography.bodyMedium.copyWith(
              fontSize: 12,
              color: isSelected
                  ? FieldColors.primaryNavy
                  : FieldColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Supplier card ───────────────────────────────────────────────────────────

class _SupplierCompareCard extends StatelessWidget {
  final MaterialListing listing;
  final CompareBadgeType badge;
  final String? aiInsightLine;
  final VoidCallback onOrder;
  final VoidCallback onViewProfile;
  final VoidCallback onMessage;

  const _SupplierCompareCard({
    required this.listing,
    required this.badge,
    this.aiInsightLine,
    required this.onOrder,
    required this.onViewProfile,
    required this.onMessage,
  });

  Color? get _accentBorder {
    if (badge == CompareBadgeType.bestValue) return FieldColors.accentAmber;
    if (badge == CompareBadgeType.anomaly) return FieldColors.statusDanger;
    return null;
  }

  String _freshnessLabel() {
    final updated = listing.priceUpdatedAt;
    if (updated == null) return 'Updated date unknown';
    final days = DateTime.now().difference(updated).inDays;
    if (days <= 0) return 'Updated today';
    return 'Updated $days days ago';
  }

  bool get _isStalePrice {
    final updated = listing.priceUpdatedAt;
    if (updated == null) return false;
    return DateTime.now().difference(updated).inDays >= 14;
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentBorder;
    final city = (listing.city ?? '').trim();
    final reviewLabel = listing.reviewCount > 0
        ? '${listing.supplierRating.toStringAsFixed(1)} (${listing.reviewCount} review${listing.reviewCount == 1 ? '' : 's'})'
        : '${listing.supplierRating.toStringAsFixed(1)} (No reviews yet)';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FieldColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: FieldColors.primaryNavy.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        listing.supplierName,
                        style: FieldTypography.titleMedium.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: FieldColors.primaryNavy,
                        ),
                      ),
                    ),
                    if (badge == CompareBadgeType.bestValue)
                      const _StatusPill(
                        label: 'Best Value',
                        background: FieldColors.accentAmber,
                        foreground: FieldColors.primaryNavy,
                      )
                    else if (badge == CompareBadgeType.anomaly)
                      const _StatusPill(
                        label: 'Above Average',
                        background: FieldColors.statusDanger,
                        foreground: Colors.white,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  listing.materialName,
                  style: FieldTypography.bodyMedium.copyWith(
                    fontSize: 12,
                    color: FieldColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (listing.brandGradeSubtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    listing.brandGradeSubtitle!,
                    style: FieldTypography.bodyMedium.copyWith(
                      fontSize: 11,
                      color: FieldColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            CurrencyFormatter.formatPKR(listing.pricePerUnit),
                            style: FieldTypography.displayLarge.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: FieldColors.accentAmber,
                              height: 1.1,
                            ),
                          ),
                          if (listing.unit.isNotEmpty)
                            Text(
                              'per ${listing.unit}',
                              style: FieldTypography.bodyMedium.copyWith(
                                fontSize: 12,
                                color: FieldColors.textSecondary,
                              ),
                            ),
                          if (listing.minOrderLabel != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              listing.minOrderLabel!,
                              style: FieldTypography.bodyMedium.copyWith(
                                fontSize: 11,
                                color: FieldColors.textMuted,
                              ),
                            ),
                          ],
                          if (listing.hasBulkDiscount) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: FieldColors.statusSuccess.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                listing.bulkDiscountDetails!,
                                style: FieldTypography.labelSmall.copyWith(
                                  color: FieldColors.statusSuccess,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        RatingStarsWidget(
                          rating: listing.supplierRating,
                          size: 14,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reviewLabel,
                          style: FieldTypography.bodyMedium.copyWith(
                            fontSize: 12,
                            color: FieldColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (aiInsightLine != null && aiInsightLine!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 12,
                        color: FieldColors.accentAmber,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          aiInsightLine!,
                          style: FieldTypography.bodyMedium.copyWith(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: FieldColors.accentAmber,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  city.isNotEmpty
                      ? '📍 $city  |  🕒 ${_freshnessLabel()}'
                      : '🕒 ${_freshnessLabel()}',
                  style: FieldTypography.bodyMedium.copyWith(
                    fontSize: 11,
                    color: _isStalePrice
                        ? FieldColors.statusWarning
                        : FieldColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onMessage,
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      size: 16,
                      color: FieldColors.primaryNavy,
                    ),
                    label: Text(
                      'Message supplier',
                      style: FieldTypography.bodyMedium.copyWith(
                        fontSize: 12,
                        color: FieldColors.primaryNavy,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: FilledButton(
                          onPressed: onOrder,
                          style: FilledButton.styleFrom(
                            backgroundColor: FieldColors.accentAmber,
                            foregroundColor: FieldColors.primaryNavy,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          child: const Text('Order Now'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          onPressed: onViewProfile,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: FieldColors.primaryNavy,
                            side: const BorderSide(
                              color: FieldColors.primaryNavy,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          child: const Text('View Profile'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (accent != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 3, color: accent),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _StatusPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Price trend CTA ─────────────────────────────────────────────────────────

class _ViewPriceTrendButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _ViewPriceTrendButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      height: 50,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: FieldColors.primaryNavy,
          side: const BorderSide(
            color: FieldColors.primaryNavy,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.show_chart,
              color: FieldColors.accentAmber,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'View Price Trend & History',
                style: FieldTypography.titleMedium.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: FieldColors.primaryNavy,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: FieldColors.textMuted.withValues(alpha: 0.9),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading, empty, error ───────────────────────────────────────────────────

class _CompareLoadingBody extends StatelessWidget {
  const _CompareLoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Shimmer.fromColors(
          baseColor: FieldColors.borderSubtle,
          highlightColor: FieldColors.surfaceWhite,
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: FieldColors.borderSubtle,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Shimmer.fromColors(
          baseColor: FieldColors.borderSubtle,
          highlightColor: FieldColors.surfaceWhite,
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: FieldColors.borderSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _CompareCardSkeleton(),
          ),
        ),
      ],
    );
  }
}

class _CompareCardSkeleton extends StatelessWidget {
  const _CompareCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: FieldColors.borderSubtle,
      highlightColor: FieldColors.surfaceWhite,
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: FieldColors.borderSubtle,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _CompareEmptyState extends StatelessWidget {
  final VoidCallback onBrowse;

  const _CompareEmptyState({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FieldSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 64,
              color: FieldColors.textMuted.withValues(alpha: 0.7),
            ),
            const SizedBox(height: FieldSpacing.md),
            Text(
              'No suppliers available',
              style: FieldTypography.titleMedium.copyWith(
                color: FieldColors.primaryNavy,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: FieldSpacing.sm),
            Text(
              'No approved suppliers offer this material in your network yet',
              style: FieldTypography.bodyMedium.copyWith(
                color: FieldColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FieldSpacing.lg),
            FilledButton(
              onPressed: onBrowse,
              style: FilledButton.styleFrom(
                backgroundColor: FieldColors.accentAmber,
                foregroundColor: FieldColors.primaryNavy,
              ),
              child: const Text('Browse other materials'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareFilteredEmptyState extends StatelessWidget {
  final VoidCallback onClearFilter;

  const _CompareFilteredEmptyState({required this.onClearFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FieldSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 48,
              color: FieldColors.textMuted.withValues(alpha: 0.6),
            ),
            const SizedBox(height: FieldSpacing.lg),
            Text(
              'No suppliers match the selected city',
              style: FieldTypography.bodyLarge.copyWith(
                color: FieldColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FieldSpacing.xl),
            OutlinedButton(
              onPressed: onClearFilter,
              child: const Text('Show all cities'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CompareErrorState({
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
              color: FieldColors.statusDanger,
              size: 40,
            ),
            const SizedBox(height: FieldSpacing.md),
            Text(
              'Could not load comparison',
              style: FieldTypography.titleMedium,
            ),
            const SizedBox(height: FieldSpacing.sm),
            Text(
              message,
              style: FieldTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FieldSpacing.lg),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
