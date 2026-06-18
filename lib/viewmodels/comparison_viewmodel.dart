import 'package:flutter/material.dart';
import '../models/material_model.dart';
import '../models/supplier_compare_model.dart';
import '../repositories/material_repository.dart';
import '../services/gemini_service.dart';

class ComparisonViewModel extends ChangeNotifier {
  final MaterialRepository _materialRepository;
  final GeminiService _geminiService;

  List<MaterialModel> _suppliers = [];
  List<MaterialModel> _filteredSuppliers = [];
  bool _isLoading = false;
  String _sortBy = 'price';
  String? _cityFilter;

  // AI State
  String? _aiResult;
  bool _isAiLoading = false;
  String? _aiError;

  ComparisonViewModel(this._materialRepository, this._geminiService);

  List<MaterialModel> get suppliers => _filteredSuppliers;
  bool get isLoading => _isLoading;
  String get sortByField => _sortBy;
  String? get aiResult => _aiResult;
  bool get isAiLoading => _isAiLoading;
  String? get aiError => _aiError;

  Future<void> loadSuppliers(String materialName) async {
    _isLoading = true;
    notifyListeners();

    try {
      _suppliers = await _materialRepository.getApprovedSuppliersForMaterial(materialName);
      _applyFiltersAndSort();
    } catch (e) {
      debugPrint("Error loading suppliers: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  void sortBy(String field) {
    _sortBy = field;
    _applyFiltersAndSort();
    notifyListeners();
  }

  void filterByCity(String? city) {
    _cityFilter = city;
    _applyFiltersAndSort();
    notifyListeners();
  }

  void _applyFiltersAndSort() {
    _filteredSuppliers = List.from(_suppliers);

    if (_cityFilter != null && _cityFilter!.isNotEmpty) {
      _filteredSuppliers = _filteredSuppliers.where((s) => s.originCity == _cityFilter).toList();
    }

    if (_sortBy == 'price') {
      _filteredSuppliers.sort((a, b) => a.pricePerUnit.compareTo(b.pricePerUnit));
    } else if (_sortBy == 'location') {
      _filteredSuppliers.sort((a, b) => a.originCity.compareTo(b.originCity));
    }
  }

  Future<void> getAiRecommendation(String query, {String locale = 'en'}) async {
    if (_suppliers.isEmpty) return;
    
    _isAiLoading = true;
    _aiError = null;
    _aiResult = null;
    notifyListeners();

    try {
      final List<SupplierCompareModel> supplierCompareData = _suppliers.map((s) => SupplierCompareModel(
        supplierUid: s.supplierId,
        businessName: s.supplierName,
        price: s.pricePerUnit,
        rating: 0.0, // Rating would need separate fetch or join
        city: s.originCity,
        isVerified: s.isCertified,
        isAnomalyFlagged: isAnomaly(s),
      )).toList();

      _aiResult = await _geminiService.getSupplierRecommendation(
        supplierCompareData, 
        query, 
        locale: locale
      );
    } catch (e) {
      _aiError = "Rate limit hit or API error. Please try again.";
    }

    _isAiLoading = false;
    notifyListeners();
  }

  bool isAnomaly(MaterialModel material) {
    if (_suppliers.isEmpty) return false;
    final avg = _suppliers.map((s) => s.pricePerUnit).reduce((a, b) => a + b) / _suppliers.length;
    return material.pricePerUnit > (avg * 1.15); // 15% above average
  }
}
