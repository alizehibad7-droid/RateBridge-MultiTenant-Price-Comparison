import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/material_model.dart';
import '../../models/rating_model.dart';
import '../../models/supplier_model.dart';
import '../../repositories/material_repository.dart';
import '../../repositories/order_repository.dart';

/// Supplier detail, catalog, and reviews for field users.
class FieldSupplierProfileViewModel extends ChangeNotifier {
  final MaterialRepository _materialRepo;
  final OrderRepository _orderRepo;

  SupplierModel? _supplier;
  double _averageRating = 0;
  List<MaterialModel> _materials = [];
  List<RatingModel> _ratings = [];
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<List<RatingModel>>? _ratingsSubscription;

  FieldSupplierProfileViewModel(this._materialRepo, this._orderRepo);

  SupplierModel? get supplier => _supplier;
  double get averageRating => _averageRating;
  List<MaterialModel> get materials => _materials;
  List<RatingModel> get recentRatings => _ratings.take(5).toList();
  int get ratingCount => _ratings.length;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  double get qualityAverage => _dimensionAverage('Quality');
  double get deliveryAverage => _dimensionAverage('Timeliness');

  Future<void> load(String companyId, String supplierUid) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _supplier = await _orderRepo.getSupplierById(supplierUid);
      _averageRating = await _materialRepo.getSupplierAverageRating(supplierUid);
      _materials =
          await _materialRepo.getCompanyMaterialsBySupplier(companyId, supplierUid);

      _ratingsSubscription?.cancel();
      _ratingsSubscription =
          _orderRepo.watchSupplierRatings(supplierUid).listen(
        (data) {
          _ratings = data;
          notifyListeners();
        },
        onError: (e) {
          _errorMessage = e.toString();
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  double _dimensionAverage(String key) {
    final values = _ratings
        .map((r) => r.dimensions[key])
        .where((v) => v != null && v > 0)
        .cast<double>()
        .toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  @override
  void dispose() {
    _ratingsSubscription?.cancel();
    super.dispose();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
