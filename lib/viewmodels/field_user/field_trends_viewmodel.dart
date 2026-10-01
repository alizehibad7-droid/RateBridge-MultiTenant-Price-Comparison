import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_constants.dart';
import '../../models/price_history_model.dart';
import '../../models/subscription_model.dart';
import '../../repositories/company_repository.dart';
import '../../repositories/material_repository.dart';
import '../../services/firestore_service.dart';

/// Price history charts for field users.
class FieldTrendsViewModel extends ChangeNotifier {
  final MaterialRepository _materialRepo;
  final CompanyRepository _companyRepo;
  final FirestoreService _firestore;
  final FirebaseAuth _auth;

  bool _isLoading = false;
  bool _isAiLoading = false;
  String? _errorMessage;
  List<PriceHistoryModel> _history = [];
  String _trendDirection = 'stable';
  String? _materialName;
  String? _supplierName;
  String? _aiInsight;
  int _aiGeneration = 0;

  FieldTrendsViewModel(
    this._materialRepo,
    this._companyRepo,
    this._firestore, {
    FirebaseAuth? auth,
  }) : _auth = auth ?? FirebaseAuth.instance;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<PriceHistoryModel> get history => _history;
  String get trendDirection => _trendDirection;
  String? get materialName => _materialName;
  String? get supplierName => _supplierName;

  bool get showAiCard =>
      (_aiInsight != null && _aiInsight!.isNotEmpty) || _isAiLoading;
  bool get isAiLoading => _isAiLoading;
  String? get aiInsight => _aiInsight;

  int get distinctMonthCount => _history
      .map((h) => '${h.timestamp.year}-${h.timestamp.month.toString().padLeft(2, '0')}')
      .toSet()
      .length;

  bool get hasEnoughDataForAi => chartPoints.length >= 3;

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
  Future<void> loadTrends(
    String companyId,
    String materialId,
    String supplierUid,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    _history = [];
    _trendDirection = 'stable';
    _materialName = null;
    _supplierName = null;
    _aiInsight = null;
    _isAiLoading = false;
    _aiGeneration++;
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

      await _enrichHistoryLabels(
        companyId: companyId,
        fallbackMaterialName: _materialName,
        fallbackSupplierUid: isAggregate ? null : supplierUid,
        fallbackSupplierName: isAggregate ? null : _supplierName,
      );

      _computeTrendDirection();
      _requestAiInsight();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Attach display names to each history point without inventing data.
  Future<void> _enrichHistoryLabels({
    required String companyId,
    String? fallbackMaterialName,
    String? fallbackSupplierUid,
    String? fallbackSupplierName,
  }) async {
    if (_history.isEmpty) return;

    final nameByUid = <String, String>{};
    if (fallbackSupplierUid != null &&
        fallbackSupplierUid.isNotEmpty &&
        (fallbackSupplierName?.trim().isNotEmpty ?? false)) {
      nameByUid[fallbackSupplierUid] = fallbackSupplierName!.trim();
    }

    // Prefer names already known from company materials for this material label.
    final materialLabel = (fallbackMaterialName ?? '').trim();
    if (materialLabel.isNotEmpty) {
      try {
        final materials = await _materialRepo.getMaterialsByNameForCompany(
          companyId,
          materialLabel,
        );
        for (final m in materials) {
          final sid = m.supplierId.trim();
          final sname = m.supplierName.trim();
          if (sid.isNotEmpty && sname.isNotEmpty) {
            nameByUid.putIfAbsent(sid, () => sname);
          }
        }
      } catch (_) {
        // Best-effort enrichment.
      }
    }

    final missingUids = _history
        .map((h) => h.supplierUid.trim())
        .where((id) => id.isNotEmpty && !nameByUid.containsKey(id))
        .toSet();

    for (final uid in missingUids) {
      try {
        final supplier = await _firestore.getSupplierById(uid);
        final name = supplier?.name.trim() ?? '';
        if (name.isNotEmpty) nameByUid[uid] = name;
      } catch (_) {
        // Leave unresolved — tooltip shows fallback.
      }
    }

    _history = _history.map((h) {
      final uid = h.supplierUid.trim().isNotEmpty
          ? h.supplierUid.trim()
          : (fallbackSupplierUid ?? '');
      final resolvedName = h.supplierName?.trim().isNotEmpty == true
          ? h.supplierName!.trim()
          : nameByUid[uid];
      final resolvedMaterial = h.materialName?.trim().isNotEmpty == true
          ? h.materialName!.trim()
          : (fallbackMaterialName?.trim().isNotEmpty == true
              ? fallbackMaterialName!.trim()
              : null);
      return h.copyWith(
        supplierUid: uid.isNotEmpty ? uid : h.supplierUid,
        supplierName: resolvedName,
        materialName: resolvedMaterial,
      );
    }).toList();
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

  Future<void> _requestAiInsight() async {
    final gen = ++_aiGeneration;
    if (!hasEnoughDataForAi) {
      _aiInsight = null;
      _isAiLoading = false;
      notifyListeners();
      return;
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      debugPrint('Trend AI skipped: user is signed out');
      return;
    }

    _isAiLoading = true;
    notifyListeners();

    final points = chartPoints;
    final dateFmt = DateFormat('MMM yyyy');
    final series = points
        .map(
          (p) =>
              '${dateFmt.format(p.timestamp)}: PKR ${p.price.toStringAsFixed(0)}',
        )
        .join('\n');
    final material = _materialName ?? 'this material';
    final supplier = _supplierName ?? 'suppliers';
    final prompt = '''
You are RateBridge Assistant for a Pakistan construction-materials buyer.

Material: $material
Supplier: $supplier
Computed trend: $_trendDirection
Price history (PKR):
$series

Write 2 short sentences for a field user: what the trend means and whether buying now or waiting is more reasonable. Use only this data. Do not invent prices.
''';

    try {
      final text = await _firestore.generateAiText(uid: uid, prompt: prompt);
      if (gen != _aiGeneration) return;
      _aiInsight = text.trim();
      debugPrint('Trend AI complete (${_aiInsight!.length} chars)');
    } catch (e) {
      debugPrint('Trend AI failed: $e');
      if (gen != _aiGeneration) return;
      _aiInsight = null;
    } finally {
      if (gen == _aiGeneration) {
        _isAiLoading = false;
        notifyListeners();
      }
    }
  }

  /// Monthly averages kept per supplier so each chart point stays attributable.
  List<PriceHistoryModel> _monthlyAverages(List<PriceHistoryModel> entries) {
    if (entries.isEmpty) return [];

    final buckets = <String, List<PriceHistoryModel>>{};
    for (final entry in entries) {
      final month =
          '${entry.timestamp.year}-${entry.timestamp.month.toString().padLeft(2, '0')}';
      final supplierKey =
          entry.supplierUid.trim().isNotEmpty ? entry.supplierUid.trim() : '_';
      final key = '$supplierKey|$month';
      buckets.putIfAbsent(key, () => []).add(entry);
    }

    final points = buckets.entries.map((entry) {
      final sample = entry.value.first;
      final avg =
          entry.value.map((e) => e.price).reduce((a, b) => a + b) /
              entry.value.length;
      final monthKey = entry.key.split('|').last;
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      return PriceHistoryModel(
        histId: entry.key,
        materialId: sample.materialId,
        supplierUid: sample.supplierUid,
        companyId: sample.companyId,
        price: avg,
        timestamp: DateTime(year, month, 1),
        supplierName: sample.supplierName,
        materialName: sample.materialName ?? _materialName,
      );
    }).toList();

    points.sort((a, b) {
      final byTime = a.timestamp.compareTo(b.timestamp);
      if (byTime != 0) return byTime;
      return a.displaySupplierName.compareTo(b.displaySupplierName);
    });
    return points;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
