import 'package:flutter/material.dart';
import '../models/material_model.dart';
import '../repositories/material_repository.dart';

class ComparisonViewModel extends ChangeNotifier {
  final MaterialRepository _materialRepository;

  List<MaterialModel> _suppliers = [];
  List<MaterialModel> _filteredSuppliers = [];
  bool _isLoading = false;
  String _sortBy = 'price';
  String? _cityFilter;

  ComparisonViewModel(this._materialRepository);

  List<MaterialModel> get suppliers => _filteredSuppliers;
  bool get isLoading => _isLoading;
  String get sortByField => _sortBy;
  bool get isAiLoading => false;
  String? get aiResult => null;
  String? get aiError => null;

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
    // AI feature removed
    return;
  }

  bool isAnomaly(MaterialModel material) {
    if (_suppliers.isEmpty) return false;
    final avg = _suppliers.map((s) => s.pricePerUnit).reduce((a, b) => a + b) / _suppliers.length;
    return material.pricePerUnit > (avg * 1.15); // 15% above average
  }
}
