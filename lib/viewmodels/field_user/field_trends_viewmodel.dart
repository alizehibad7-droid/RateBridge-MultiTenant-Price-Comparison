import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../models/price_history_model.dart';
import '../../models/subscription_model.dart';
import '../../repositories/company_repository.dart';
import '../../repositories/material_repository.dart';
import '../../services/gemini_service.dart';

/// Price history charts and AI-generated trend insights for field users.
class FieldTrendsViewModel extends ChangeNotifier {
  final MaterialRepository _materialRepo;
  final GeminiService _geminiService;
  final CompanyRepository _companyRepo;

  bool _isLoading = false;
  bool _isAiLoading = false;
  String? _errorMessage;
  String? _aiInsight;
  List<PriceHistoryModel> _history = [];
  String _trendDirection = 'stable';
  String? _materialName;
  String? _supplierName;

  FieldTrendsViewModel(
    this._materialRepo,
    this._geminiService,
    this._companyRepo,
  );

  bool get isLoading => _isLoading;
  bool get isAiLoading => _isAiLoading;
  String? get errorMessage => _errorMessage;
  String? get aiInsight => _aiInsight;
  List<PriceHistoryModel> get history => _history;
  String get trendDirection => _trendDirection;
  String? get materialName => _materialName;
  String? get supplierName => _supplierName;

  bool get showAiCard => _aiInsight != null && _aiInsight!.isNotEmpty;

  int get distinctMonthCount => _history
      .map((h) => '${h.timestamp.year}-${h.timestamp.month.toString().padLeft(2, '0')}')
      .toSet()
      .length;

  bool get hasEnoughDataForAi =>
      distinctMonthCount >= AppConstants.priceHistoryMinForAI;

  List<PriceHistoryModel> get chartPoints {
    final monthly = _monthlyAverages(_history);
    if (monthly.length >= 2) return monthly;
    if (_history.length >= 2) return _history;
    return [];
  }

  bool get hasEnoughChartData => chartPoints.length >= 2;

  double? get currentPrice =>
      _history.isNotEmpty ? _history.last.price : null;

  double? get periodChangePercent {
    if (_history.length < 2) return null;
    final first = _history.first.price;
    final last = _history.last.price;
    if (first == 0) return null;
    return ((last - first) / first) * 100;
  }

  double? get lowestPrice {
    if (_history.isEmpty) return null;
    return _history.map((h) => h.price).reduce((a, b) => a < b ? a : b);
  }

  double? get highestPrice {
    if (_history.isEmpty) return null;
    return _history.map((h) => h.price).reduce((a, b) => a > b ? a : b);
  }

  /// Backward-compatible alias.
  Future<void> loadPriceTrend(
    String companyId,
    String materialId,
    String supplierUid,
  ) =>
      loadTrends(companyId, materialId, supplierUid);

  /// Loads supplier-specific history via [materialId] + [supplierUid].
  /// When [supplierUid] is `_` or `all`, [materialId] is treated as material
  /// name and company-wide history is merged (legacy aggregate route).
  Future<void> loadTrends(
    String companyId,
    String materialId,
    String supplierUid,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    _history = [];
    _aiInsight = null;
    _isAiLoading = false;
    _trendDirection = 'stable';
    _materialName = null;
    _supplierName = null;
    notifyListeners();

    try {
      final isAggregate = supplierUid == '_' ||
          supplierUid == 'all' ||
          supplierUid.isEmpty;

      // Enforce Price Trend History Depth Limit
      final company = await _companyRepo.getCompanyById(companyId);
      final planKey = company?.plan ?? 'free';
      final plan = kPlans.firstWhere((p) => p.planKey == planKey,
          orElse: () => kPlans.first);

      int months = AppConstants.priceHistoryMonths;
      if (plan.priceHistoryDays != -1) {
        // Free plan: last 30 days
        months = (plan.priceHistoryDays / 30).ceil();
      }

      if (isAggregate) {
        _materialName = materialId;
        _supplierName = 'All suppliers';
        _history = await _materialRepo.getPriceTrendForMaterial(
          companyId,
          materialId,
          months: months,
        );
      } else {
        final linked = await _materialRepo.isSupplierLinkedToCompany(
          companyId,
          supplierUid,
        );
        if (!linked) {
          throw Exception(
            'This supplier is not partnered with your company.',
          );
        }

        final material = await _materialRepo.getMaterialById(materialId);
        if (material == null) {
          throw Exception('Material not found');
        }
        if (material.supplierId != supplierUid) {
          throw Exception(
              'This material does not belong to the selected supplier');
        }
        _materialName = material.name;
        _supplierName = material.supplierName;
        _history = await _materialRepo.getSupplierMaterialPriceTrend(
          materialId: materialId,
          supplierUid: supplierUid,
          companyId: companyId,
          months: months,
        );
      }

      _computeTrendDirection();

      if (hasEnoughDataForAi && _materialName != null) {
        await _loadAiInsight(_materialName!);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAiInsight(String materialName) async {
    _isAiLoading = true;
    _aiInsight = null;
    notifyListeners();

    try {
      final result = await _geminiService.getPriceTrendInsight(
        _history,
        materialName,
        locale: 'en',
      );
      final trimmed = result.trim();
      if (trimmed.isNotEmpty &&
          !trimmed.toLowerCase().contains('temporarily unavailable') &&
          !trimmed.toLowerCase().contains('rate limit') &&
          !trimmed.toLowerCase().contains('insufficient price history')) {
        _aiInsight = trimmed;
      }
    } catch (_) {
      _aiInsight = null;
    } finally {
      _isAiLoading = false;
      notifyListeners();
    }
  }

  void _computeTrendDirection() {
    if (_history.length < 2) {
      _trendDirection = 'stable';
      return;
    }
    final first = _history.first.price;
    final last = _history.last.price;
    const threshold = AppConstants.priceTrendChangeThreshold;
    if (last > first * (1 + threshold)) {
      _trendDirection = 'up';
    } else if (last < first * (1 - threshold)) {
      _trendDirection = 'down';
    } else {
      _trendDirection = 'stable';
    }
  }

  List<PriceHistoryModel> _monthlyAverages(List<PriceHistoryModel> entries) {
    if (entries.isEmpty) return [];

    final buckets = <String, List<double>>{};
    for (final entry in entries) {
      final key =
          '${entry.timestamp.year}-${entry.timestamp.month.toString().padLeft(2, '0')}';
      buckets.putIfAbsent(key, () => []).add(entry.price);
    }

    return buckets.entries.map((entry) {
      final parts = entry.key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
      return PriceHistoryModel(
        histId: entry.key,
        materialId: '',
        supplierUid: '',
        companyId: '',
        price: avg,
        timestamp: DateTime(year, month, 1),
      );
    }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
