import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../constants/route_names.dart';
import '../../../models/material_model.dart';
import '../../../models/price_history_model.dart';
import '../../../repositories/material_repository.dart';
import '../../../services/ai_context_service.dart';
import '../../../theme/field_theme.dart';
import '../../../utils/app_navigation.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/firestore_seed.dart';
import '../../../viewmodels/field_user/field_session_viewmodel.dart';
import '../../../viewmodels/field_user/field_trends_viewmodel.dart';
import '../widgets/field_material_card.dart';
import 'field_price_trend_chart.dart';

enum _TrendRange { threeMonths, sixMonths, oneYear }

extension on _TrendRange {
  String get label => switch (this) {
        _TrendRange.threeMonths => '3M',
        _TrendRange.sixMonths => '6M',
        _TrendRange.oneYear => '1Y',
      };

  int get months => switch (this) {
        _TrendRange.threeMonths => 3,
        _TrendRange.sixMonths => 6,
        _TrendRange.oneYear => 12,
      };

  String get displayLabel => switch (this) {
        _TrendRange.threeMonths => 'Last 3 months',
        _TrendRange.sixMonths => 'Last 6 months',
        _TrendRange.oneYear => 'Last 12 months',
      };
}

class FieldPriceTrendsView extends StatefulWidget {
  final String materialId;
  final String supplierUid;

  const FieldPriceTrendsView({
    super.key,
    required this.materialId,
    required this.supplierUid,
  });

  @override
  State<FieldPriceTrendsView> createState() => _FieldPriceTrendsViewState();
}

class _FieldPriceTrendsViewState extends State<FieldPriceTrendsView> {
  static const _scaffoldBg = FieldColors.screenBackground;
  static const _appBarNavy = FieldColors.primaryNavy;

  _TrendRange _selectedRange = _TrendRange.sixMonths;
  bool _hasUserPickedRange = false;
  late String _activeMaterialId;
  late String _activeSupplierUid;
  List<MaterialModel> _supplierOptions = [];
  String? _category;
  String? _unit;
  bool _isSeedingTrend = false;

  @override
  void initState() {
    super.initState();
    _activeMaterialId = widget.materialId;
    _activeSupplierUid = widget.supplierUid;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final companyId = context.read<FieldSessionViewModel>().companyId;
    if (companyId == null) return;
    await context.read<FieldTrendsViewModel>().loadTrends(
          companyId,
          _activeMaterialId,
          _activeSupplierUid,
        );
    if (!mounted) return;
    _syncDefaultRange(context.read<FieldTrendsViewModel>());
    await _loadSupplierOptions(companyId);
    if (!mounted) return;
    final vm = context.read<FieldTrendsViewModel>();
    context.read<AiContextService>().updateContext('price_trend', {
      'materialName': vm.materialName,
      'currentPrice': vm.currentPrice,
      'lowestPrice': vm.lowestPrice,
      'highestPrice': vm.highestPrice,
      'trendDirection': vm.trendDirection,
      'monthCount': vm.distinctMonthCount,
    });
  }

  Future<void> _refresh() async {
    final companyId = context.read<FieldSessionViewModel>().companyId;
    if (companyId == null) return;
    await context.read<FieldTrendsViewModel>().loadTrends(
          companyId,
          _activeMaterialId,
          _activeSupplierUid,
        );
    if (!mounted) return;
    _syncDefaultRange(context.read<FieldTrendsViewModel>());
    await _loadSupplierOptions(companyId);
  }

  void _syncDefaultRange(FieldTrendsViewModel vm) {
    if (_hasUserPickedRange) return;
    final months = vm.distinctMonthCount;
    if (months <= 0) return;
    final next = months <= 3
        ? _TrendRange.threeMonths
        : months <= 6
            ? _TrendRange.sixMonths
            : _TrendRange.oneYear;
    if (_selectedRange != next) {
      setState(() => _selectedRange = next);
    }
  }

  String _cleanMaterialTitle(String raw) {
    var text = raw.trim();
    text = text.replaceFirst(RegExp(r'[:：\s]+$'), '');
    return text;
  }

  String _monthsLabel(int count) => count == 1 ? '1 month' : '$count months';

  Future<void> _loadSupplierOptions(String companyId) async {
    final vm = context.read<FieldTrendsViewModel>();
    final repo = context.read<MaterialRepository>();
    final materialName = vm.materialName ?? widget.materialId;

    try {
      List<MaterialModel> materials;
      if (_isAggregateSupplier(_activeSupplierUid)) {
        materials =
            await repo.getMaterialsByNameForCompany(companyId, materialName);
      } else {
        final material = await repo.getMaterialById(_activeMaterialId);
        if (material == null) {
          materials = [];
        } else {
          materials = await repo.getMaterialsByNameForCompany(
            companyId,
            material.name,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _supplierOptions = materials;
        if (materials.isNotEmpty) {
          final current = materials.cast<MaterialModel?>().firstWhere(
                (m) => m!.id == _activeMaterialId,
                orElse: () => materials.first,
              );
          _category = current?.category ?? materials.first.category;
          _unit = current?.unit ?? materials.first.unit;
        }
      });
    } catch (_) {
      // Supplier selector is optional — ignore lookup failures.
    }
  }

  bool _isAggregateSupplier(String uid) =>
      uid == '_' || uid == 'all' || uid.isEmpty;

  Future<void> _switchSupplier(MaterialModel material) async {
    setState(() {
      _activeMaterialId = material.id;
      _activeSupplierUid = material.supplierId;
      _category = material.category;
      _unit = material.unit;
    });
    await _refresh();
  }

  void _showSupplierPicker(FieldTrendsViewModel vm) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        decoration: BoxDecoration(
          color: FieldColors.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FieldColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Select Supplier',
                  style: FieldTypography.titleMedium.copyWith(
                    color: FieldColors.primaryNavy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ..._supplierOptions.map((material) {
                final selected = material.id == _activeMaterialId;
                return ListTile(
                  title: Text(
                    material.supplierName,
                    style: FieldTypography.bodyLarge.copyWith(
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: FieldColors.primaryNavy,
                    ),
                  ),
                  subtitle: Text(
                    CurrencyFormatter.formatPKR(material.pricePerUnit),
                    style: FieldTypography.bodyMedium,
                  ),
                  trailing: selected
                      ? const Icon(
                          Icons.check_circle,
                          color: FieldColors.accentAmber,
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _switchSupplier(material);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _openCompare(FieldTrendsViewModel vm) {
    final materialName = vm.materialName ?? widget.materialId;
    context.push(
      RouteNames.fieldCompareOf(materialName),
      extra: materialName,
    );
  }

  void _browseMaterials() {
    context.push(RouteNames.fieldMarketplace);
  }

  Future<void> _seedTrendData() async {
    final companyId = context.read<FieldSessionViewModel>().companyId;
    if (companyId == null) return;

    if (_isAggregateSupplier(_activeSupplierUid)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a specific supplier to seed trend data'),
        ),
      );
      return;
    }

    setState(() => _isSeedingTrend = true);
    try {
      final message = await FirestoreSeed.seedMaterialPriceTrend(
        FirebaseFirestore.instance,
        companyId: companyId,
        materialId: _activeMaterialId,
        supplierUid: _activeSupplierUid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Seed failed: $e'),
          backgroundColor: FieldColors.statusDanger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSeedingTrend = false);
    }
  }

  List<PriceHistoryModel> _filterByRange(List<PriceHistoryModel> points) {
    if (points.isEmpty) return points;
    final end = points.last.timestamp;
    final cutoff = DateTime(end.year, end.month - _selectedRange.months, 1);
    final filtered =
        points.where((p) => !p.timestamp.isBefore(cutoff)).toList();
    return filtered.length >= 2 ? filtered : points;
  }

  int _distinctMonths(List<PriceHistoryModel> points) => points
      .map(
        (h) =>
            '${h.timestamp.year}-${h.timestamp.month.toString().padLeft(2, '0')}',
      )
      .toSet()
      .length;

  ({double? diff, double? percent, bool noChange}) _thirtyDayChange(
    List<PriceHistoryModel> points,
  ) {
    if (points.isEmpty) {
      return (diff: null, percent: null, noChange: true);
    }
    final latest = points.last;
    final cutoff = latest.timestamp.subtract(const Duration(days: 30));
    PriceHistoryModel? baseline;
    for (final point in points) {
      if (!point.timestamp.isAfter(cutoff)) {
        baseline = point;
      }
    }
    baseline ??= points.length > 1 ? points.first : latest;
    final diff = latest.price - baseline.price;
    if (diff.abs() < 0.01) {
      return (diff: 0, percent: 0, noChange: true);
    }
    final percent =
        baseline.price == 0 ? null : (diff / baseline.price) * 100;
    return (diff: diff, percent: percent, noChange: false);
  }

  _PriceStats _computeStats(List<PriceHistoryModel> points) {
    if (points.isEmpty) {
      return const _PriceStats();
    }
    PriceHistoryModel? lowest = points.first;
    PriceHistoryModel? highest = points.first;
    var sum = 0.0;
    for (final point in points) {
      sum += point.price;
      if (point.price < lowest!.price) lowest = point;
      if (point.price > highest!.price) highest = point;
    }
    return _PriceStats(
      lowest: lowest,
      highest: highest,
      average: sum / points.length,
      monthCount: _distinctMonths(points),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FieldTrendsViewModel>();
    final materialLabel = _cleanMaterialTitle(vm.materialName ?? widget.materialId);
    final chartPoints = _filterByRange(vm.chartPoints);
    final stats = _computeStats(chartPoints);
    final change = _thirtyDayChange(vm.chartPoints);
    final showSupplierPicker = _supplierOptions.length > 1 &&
        !_isAggregateSupplier(_activeSupplierUid);
    final historyMonths = _distinctMonths(vm.chartPoints);

    return Theme(
      data: FieldTheme.theme,
      child: Scaffold(
        backgroundColor: _scaffoldBg,
        appBar: AppBar(
          backgroundColor: _appBarNavy,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          leading: AppNavigation.leading(context, color: Colors.white),
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            materialLabel,
            style: FieldTypography.titleMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: vm.isLoading
            ? const _TrendsLoadingBody()
            : vm.errorMessage != null
                ? _TrendsErrorState(message: vm.errorMessage!, onRetry: _load)
                : vm.history.isEmpty
                    ? _TrendsEmptyState(
                        onBrowse: _browseMaterials,
                        onSeedTrend: kDebugMode ? _seedTrendData : null,
                        isSeeding: _isSeedingTrend,
                      )
                    : RefreshIndicator(
                        color: FieldColors.primaryNavy,
                        onRefresh: _refresh,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.only(bottom: 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: FieldSpacing.sm),
                              _MaterialSummaryCard(
                                materialName: materialLabel,
                                supplierName: vm.supplierName ?? '—',
                                category: _category ?? 'Material',
                                showSupplierPicker: showSupplierPicker,
                                onSupplierTap: () => _showSupplierPicker(vm),
                              ),
                              _CurrentPriceStrip(
                                latestPrice: vm.currentPrice,
                                unit: _unit ?? 'unit',
                                change: change,
                                monthsLabel: _monthsLabel(historyMonths),
                              ),
                              _TimeRangeSelector(
                                selected: _selectedRange,
                                onSelected: (range) => setState(() {
                                  _hasUserPickedRange = true;
                                  _selectedRange = range;
                                }),
                              ),
                              _ChartCard(
                                rangeLabel: _selectedRange.displayLabel,
                                points: chartPoints,
                                showInsightWarning: chartPoints.length < 3,
                                insightText: vm.isAiLoading
                                    ? 'Analyzing this trend…'
                                    : vm.aiInsight,
                              ),
                              _PriceStatisticsCard(
                                stats: stats,
                                averageSubtitle:
                                    'over ${_monthsLabel(stats.monthCount)}',
                              ),
                              _CompareSuppliersButton(
                                onPressed: () => _openCompare(vm),
                              ),
                              if (kDebugMode) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: OutlinedButton(
                                    onPressed:
                                        _isSeedingTrend ? null : _seedTrendData,
                                    child: _isSeedingTrend
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Seed Trend Data'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
      ),
    );
  }
}

class _PriceStats {
  final PriceHistoryModel? lowest;
  final PriceHistoryModel? highest;
  final double? average;
  final int monthCount;

  const _PriceStats({
    this.lowest,
    this.highest,
    this.average,
    this.monthCount = 0,
  });
}

// ─── Shared decoration ───────────────────────────────────────────────────────

BoxDecoration _panelCardDecoration({Color? borderColor, Color? color}) =>
    FieldTheme.cardDecoration(borderColor: borderColor).copyWith(
      color: color ?? FieldColors.surfaceWhite,
    );

Widget _shimmerBox({required double height, double? width}) {
  return Shimmer.fromColors(
    baseColor: FieldColors.borderSubtle,
    highlightColor: FieldColors.surfaceWhite,
    child: Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: FieldColors.borderSubtle,
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}

// ─── Part 1: Material summary ──────────────────────────────────────────────────

class _MaterialSummaryCard extends StatelessWidget {
  final String materialName;
  final String supplierName;
  final String category;
  final bool showSupplierPicker;
  final VoidCallback onSupplierTap;

  const _MaterialSummaryCard({
    required this.materialName,
    required this.supplierName,
    required this.category,
    required this.showSupplierPicker,
    required this.onSupplierTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        FieldSpacing.md,
        FieldSpacing.sm,
        FieldSpacing.md,
        0,
      ),
      padding: const EdgeInsets.all(FieldSpacing.md),
      decoration: _panelCardDecoration(),
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
              size: 24,
              color: FieldColors.primaryNavy,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  materialName,
                  style: FieldTypography.titleMedium.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: FieldColors.primaryNavy,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  supplierName,
                  style: FieldTypography.bodyMedium.copyWith(
                    fontSize: 12,
                    color: FieldColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (showSupplierPicker) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onSupplierTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: FieldColors.primaryNavy,
                side: const BorderSide(color: FieldColors.primaryNavy),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                supplierName,
                style: FieldTypography.labelSmall.copyWith(
                  fontSize: 11,
                  color: FieldColors.primaryNavy,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Part 2: Current price strip ─────────────────────────────────────────────

class _CurrentPriceStrip extends StatelessWidget {
  final double? latestPrice;
  final String unit;
  final ({double? diff, double? percent, bool noChange}) change;
  final String monthsLabel;

  const _CurrentPriceStrip({
    required this.latestPrice,
    required this.unit,
    required this.change,
    required this.monthsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        FieldSpacing.md,
        FieldSpacing.md,
        FieldSpacing.md,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: FieldSpacing.md,
        vertical: 14,
      ),
      decoration: _panelCardDecoration(
        borderColor: FieldColors.accentAmber,
        color: FieldColors.accentAmberSoft,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _PriceMetric(
                label: 'Current Price',
                value: latestPrice != null
                    ? CurrencyFormatter.formatPKR(latestPrice!)
                    : '—',
                valueColor: FieldColors.accentAmber,
                subtitle: 'per $unit',
              ),
            ),
            _verticalDivider(),
            Expanded(
              child: _PriceMetric(
                label: '30-Day Change',
                child: _ChangeValue(change: change),
              ),
            ),
            _verticalDivider(),
            Expanded(
              child: _PriceMetric(
                label: 'Data Points',
                value: monthsLabel,
                valueColor: FieldColors.primaryNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: FieldSpacing.sm),
      color: FieldColors.borderSubtle,
    );
  }
}

class _PriceMetric extends StatelessWidget {
  final String label;
  final String? value;
  final Color? valueColor;
  final String? subtitle;
  final Widget? child;

  const _PriceMetric({
    required this.label,
    this.value,
    this.valueColor,
    this.subtitle,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: FieldTypography.labelSmall.copyWith(
            fontSize: 11,
            color: FieldColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        if (child != null)
          child!
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value ?? '—',
              maxLines: 1,
              style: FieldTypography.titleMedium.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: valueColor ?? FieldColors.primaryNavy,
              ),
            ),
          ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: FieldTypography.labelSmall.copyWith(
              fontSize: 11,
              color: FieldColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _ChangeValue extends StatelessWidget {
  final ({double? diff, double? percent, bool noChange}) change;

  const _ChangeValue({required this.change});

  @override
  Widget build(BuildContext context) {
    if (change.noChange || change.diff == null) {
      return Row(
        children: [
          const Icon(
            Icons.trending_flat,
            size: 16,
            color: FieldColors.statusMuted,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'No change',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FieldTypography.titleMedium.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: FieldColors.statusMuted,
              ),
            ),
          ),
        ],
      );
    }

    final isUp = change.diff! > 0;
    final color = isUp ? FieldColors.statusDanger : FieldColors.statusSuccess;
    final percentText = change.percent == null
        ? null
        : '${isUp ? '+' : ''}${change.percent!.toStringAsFixed(1)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isUp ? Icons.trending_up : Icons.trending_down,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  CurrencyFormatter.formatPKR(change.diff!.abs()),
                  maxLines: 1,
                  style: FieldTypography.titleMedium.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (percentText != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              percentText,
              style: FieldTypography.labelSmall.copyWith(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Part 3: Time range ──────────────────────────────────────────────────────

class _TimeRangeSelector extends StatelessWidget {
  final _TrendRange selected;
  final ValueChanged<_TrendRange> onSelected;

  const _TimeRangeSelector({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FieldSpacing.md,
        FieldSpacing.md,
        FieldSpacing.md,
        0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _TrendRange.values.map((range) {
          final isActive = range == selected;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelected(range),
                borderRadius: BorderRadius.circular(20),
                child: Ink(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isActive ? FieldColors.accentAmber : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive
                          ? FieldColors.accentAmber
                          : FieldColors.borderSubtle,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      range.label,
                      style: FieldTypography.labelSmall.copyWith(
                        fontSize: 12,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                        color: isActive
                            ? FieldColors.primaryNavy
                            : FieldColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Part 4: Chart card ────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  final String rangeLabel;
  final List<PriceHistoryModel> points;
  final bool showInsightWarning;
  final String? insightText;

  const _ChartCard({
    required this.rangeLabel,
    required this.points,
    required this.showInsightWarning,
    this.insightText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        FieldSpacing.md,
        FieldSpacing.md,
        FieldSpacing.md,
        0,
      ),
      padding: const EdgeInsets.all(FieldSpacing.md),
      decoration: _panelCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Price History',
                style: FieldTypography.titleMedium.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: FieldColors.primaryNavy,
                ),
              ),
              const Spacer(),
              Text(
                rangeLabel,
                style: FieldTypography.labelSmall.copyWith(
                  fontSize: 12,
                  color: FieldColors.accentAmber,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (points.length >= 2)
            FieldPriceTrendChart(points: points)
          else
            SizedBox(
              height: 200,
              child: Center(
                child: Text(
                  'Not enough data points for chart',
                  style: FieldTypography.bodyMedium,
                ),
              ),
            ),
          if (insightText != null &&
              insightText!.isNotEmpty &&
              points.length >= 3) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: FieldColors.accentAmber.withValues(alpha: 0.08),
                border: const Border(
                  left: BorderSide(
                    color: FieldColors.accentAmber,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: FieldColors.accentAmber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insightText!,
                      style: FieldTypography.bodyMedium.copyWith(
                        fontSize: 12,
                        color: FieldColors.primaryNavy,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (showInsightWarning) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FieldColors.accentAmber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: FieldColors.accentAmber.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: FieldColors.accentAmber.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Trend insight requires at least 3 months of data. '
                      'Currently showing ${points.length} data point(s).',
                      style: FieldTypography.bodyMedium.copyWith(
                        fontSize: 11,
                        color: FieldColors.primaryNavy,
                        height: 1.4,
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
}

// ─── Part 5: Statistics ──────────────────────────────────────────────────────

class _PriceStatisticsCard extends StatelessWidget {
  final _PriceStats stats;
  final String averageSubtitle;

  const _PriceStatisticsCard({
    required this.stats,
    required this.averageSubtitle,
  });

  String _monthLabel(PriceHistoryModel? point) {
    if (point == null) return '—';
    return DateFormat('MMM yyyy').format(point.timestamp);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        FieldSpacing.md,
        FieldSpacing.md,
        FieldSpacing.md,
        0,
      ),
      padding: const EdgeInsets.all(FieldSpacing.md),
      decoration: _panelCardDecoration(),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatColumn(
                label: 'Lowest',
                value: stats.lowest != null
                    ? CurrencyFormatter.formatPKR(stats.lowest!.price)
                    : '—',
                valueColor: FieldColors.statusSuccess,
                subtitle: _monthLabel(stats.lowest),
              ),
            ),
            _statDivider(),
            Expanded(
              child: _StatColumn(
                label: 'Highest',
                value: stats.highest != null
                    ? CurrencyFormatter.formatPKR(stats.highest!.price)
                    : '—',
                valueColor: FieldColors.statusDanger,
                subtitle: _monthLabel(stats.highest),
              ),
            ),
            _statDivider(),
            Expanded(
              child: _StatColumn(
                label: 'Average',
                value: stats.average != null
                    ? CurrencyFormatter.formatPKR(stats.average!)
                    : '—',
                valueColor: FieldColors.primaryNavy,
                subtitle: averageSubtitle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: FieldColors.borderSubtle,
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final String subtitle;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: FieldTypography.labelSmall.copyWith(
            fontSize: 11,
            color: FieldColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: FieldTypography.titleMedium.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: FieldTypography.labelSmall.copyWith(
            fontSize: 10,
            color: FieldColors.textSecondary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── Part 7: Compare CTA ─────────────────────────────────────────────────────

class _CompareSuppliersButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CompareSuppliersButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FieldSpacing.md,
        FieldSpacing.md,
        FieldSpacing.md,
        FieldSpacing.md,
      ),
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: FieldColors.accentAmber,
            foregroundColor: FieldColors.primaryNavy,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.compare_arrows, color: Colors.white, size: 20),
          label: Text(
            'Compare All Suppliers for This Material',
            style: FieldTypography.titleMedium.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: FieldColors.primaryNavy,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Loading / empty / error ─────────────────────────────────────────────────

class _TrendsLoadingBody extends StatelessWidget {
  const _TrendsLoadingBody();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FieldSpacing.md,
              FieldSpacing.sm,
              FieldSpacing.md,
              0,
            ),
            child: _shimmerBox(height: 76),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FieldSpacing.md,
              FieldSpacing.md,
              FieldSpacing.md,
              0,
            ),
            child: _shimmerBox(height: 88),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FieldSpacing.md,
              FieldSpacing.md,
              FieldSpacing.md,
              0,
            ),
            child: _shimmerBox(height: 34),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FieldSpacing.md,
              FieldSpacing.md,
              FieldSpacing.md,
              0,
            ),
            child: _shimmerBox(height: 248),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FieldSpacing.md,
              FieldSpacing.md,
              FieldSpacing.md,
              FieldSpacing.md,
            ),
            child: _shimmerBox(height: 88),
          ),
        ],
      ),
    );
  }
}

class _TrendsEmptyState extends StatelessWidget {
  final VoidCallback onBrowse;
  final VoidCallback? onSeedTrend;
  final bool isSeeding;

  const _TrendsEmptyState({
    required this.onBrowse,
    this.onSeedTrend,
    this.isSeeding = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.show_chart,
              size: 64,
              color: FieldColors.textMuted.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(
              'No Price Data Yet',
              style: FieldTypography.titleMedium.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: FieldColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Price history will appear here once this material has been '
              'tracked for at least one month.',
              textAlign: TextAlign.center,
              style: FieldTypography.bodyMedium.copyWith(
                fontSize: 13,
                color: FieldColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onBrowse,
              style: OutlinedButton.styleFrom(
                foregroundColor: FieldColors.accentAmber,
                side: const BorderSide(color: FieldColors.accentAmber),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text('Browse Other Materials'),
            ),
            if (onSeedTrend != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: isSeeding ? null : onSeedTrend,
                child: isSeeding
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Seed Trend Data'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _TrendsErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: FieldColors.statusDanger,
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load price trends',
              style: FieldTypography.titleMedium.copyWith(
                color: FieldColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: FieldTypography.bodyMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
