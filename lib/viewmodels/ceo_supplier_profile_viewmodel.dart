import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/material_model.dart';
import '../models/rating_model.dart';
import '../models/supplier_model.dart';
import '../repositories/material_repository.dart';
import '../repositories/order_repository.dart';
import '../utils/app_exception.dart';

/// CEO-facing supplier profile: overview, catalog, reviews, partnership context.
class CeoSupplierProfileViewModel extends ChangeNotifier {
  final MaterialRepository _materialRepo;
  final OrderRepository _orderRepo;

  SupplierModel? _supplier;
  List<MaterialModel> _materials = [];
  List<RatingModel> _ratings = [];
  double _averageRating = 0;
  int _ratingCount = 0;
  int _companyFulfilledOrders = 0;
  double _companyOnTimeRate = 0;
  bool _isLoading = false;
  String? _errorMessage;
  String? _loadedSupplierId;
  String? _loadedCompanyId;
  StreamSubscription<List<RatingModel>>? _ratingsSub;

  CeoSupplierProfileViewModel(this._materialRepo, this._orderRepo);

  SupplierModel? get supplier => _supplier;
  List<MaterialModel> get materials => List.unmodifiable(_materials);
  List<RatingModel> get recentRatings => _ratings.take(8).toList(growable: false);
  int get ratingCount => _ratingCount > 0 ? _ratingCount : _ratings.length;
  double get averageRating => _averageRating;
  int get companyFulfilledOrders => _companyFulfilledOrders;
  double get companyOnTimeRate => _companyOnTimeRate;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get loadedSupplierId => _loadedSupplierId;

  double get qualityAverage => _dimensionAverage('Quality');
  double get deliveryAverage => _dimensionAverage('Timeliness');

  Future<void> load({
    required String supplierId,
    String? companyId,
  }) async {
    final id = supplierId.trim();
    if (id.isEmpty) {
      _errorMessage = 'Missing supplier id.';
      _supplier = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    if (_loadedSupplierId != id) {
      _supplier = null;
      _materials = [];
      _ratings = [];
      _averageRating = 0;
      _ratingCount = 0;
      _companyFulfilledOrders = 0;
      _companyOnTimeRate = 0;
    }
    _loadedSupplierId = id;
    _loadedCompanyId = companyId;
    notifyListeners();

    try {
      final supplier = await _orderRepo.getSupplierById(id);
      if (supplier == null) {
        _supplier = null;
        _materials = [];
        _ratings = [];
        _averageRating = 0;
        _ratingCount = 0;
        _companyFulfilledOrders = 0;
        _companyOnTimeRate = 0;
        _errorMessage = 'Supplier not found.';
        return;
      }

      _supplier = supplier;

      final results = await Future.wait([
        _materialRepo.getListedMaterialsForSupplier(id),
        _materialRepo.getSupplierRatingStats(id),
        if (companyId != null && companyId.isNotEmpty)
          _materialRepo.getSupplierOrderStats(id, companyId: companyId)
        else
          Future.value(<String, dynamic>{}),
      ]);

      _materials = results[0] as List<MaterialModel>;
      final stats = results[1] as ({double average, int count});
      _averageRating = stats.average > 0 ? stats.average : supplier.rating;
      _ratingCount = stats.count;

      final orderStats = results[2] as Map<String, dynamic>;
      _companyFulfilledOrders =
          (orderStats['totalFulfilled'] as num?)?.toInt() ?? 0;
      _companyOnTimeRate =
          (orderStats['onTimeRate'] as num?)?.toDouble() ?? 0;

      await _ratingsSub?.cancel();
      _ratingsSub = _orderRepo.watchSupplierRatings(id).listen(
        (data) {
          _ratings = data;
          if (_ratingCount == 0 && data.isNotEmpty) {
            _ratingCount = data.length;
          }
          notifyListeners();
        },
        onError: (Object e) {
          debugPrint('CeoSupplierProfile ratings stream: $e');
        },
      );
    } on AppException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> retry() async {
    final id = _loadedSupplierId;
    if (id == null || id.isEmpty) return;
    await load(supplierId: id, companyId: _loadedCompanyId);
  }

  double _dimensionAverage(String key) {
    final values = _ratings
        .map((r) => r.dimensions[key])
        .whereType<num>()
        .map((v) => v.toDouble())
        .where((v) => v > 0)
        .toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ratingsSub?.cancel();
    super.dispose();
  }
}
