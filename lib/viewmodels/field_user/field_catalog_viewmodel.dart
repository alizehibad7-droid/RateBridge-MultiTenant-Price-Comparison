import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/material_model.dart';
import '../../models/category_model.dart';
import '../../repositories/material_repository.dart';

enum CatalogSortOption {
  priceAsc('price_asc', 'Price: Low to High'),
  priceDesc('price_desc', 'Price: High to Low'),
  rating('rating', 'Rating: High to Low'),
  newest('newest', 'Newest First');

  final String value;
  final String label;
  const CatalogSortOption(this.value, this.label);

  static CatalogSortOption fromValue(String value) {
    return CatalogSortOption.values.firstWhere(
      (o) => o.value == value,
      orElse: () => CatalogSortOption.priceAsc,
    );
  }
}

/// Materials browsing, search, and category filtering for field users.
class FieldCatalogViewModel extends ChangeNotifier {
  final MaterialRepository _materialRepo;

  bool _isLoading = false;
  bool _catalogReady = false;
  String? _errorMessage;
  List<MaterialModel> _materials = [];
  List<MaterialModel> _filteredMaterials = [];
  List<MaterialModel> _searchResults = [];
  List<MaterialModel> _recentMaterials = [];
  List<MaterialModel> _recentlyViewedMaterials = [];
  List<CategoryModel> _categories = [];
  String? _categoryFilter;
  CatalogSortOption _sortOption = CatalogSortOption.priceAsc;
  final Map<String, double> _supplierRatings = {};
  StreamSubscription<List<MaterialModel>>? _materialsSubscription;
  String? _watchingCompanyId;

  FieldCatalogViewModel(this._materialRepo);

  @override
  void dispose() {
    _materialsSubscription?.cancel();
    super.dispose();
  }

  void _watchCompanyMaterials(String companyId) {
    if (_watchingCompanyId == companyId && _materialsSubscription != null) {
      _catalogReady = true;
      _isLoading = false;
      _applyFilters();
      notifyListeners();
      return;
    }
    _materialsSubscription?.cancel();
    _watchingCompanyId = companyId;
    _materialsSubscription =
        _materialRepo.getCompanyMaterials(companyId).listen(
      (materials) async {
        if (materials.isNotEmpty) {
          _materials = materials;
        } else {
          _materials =
              await _materialRepo.getPopularMaterials(companyId: companyId);
        }
        _completeCatalogLoad();
      },
      onError: (Object e) {
        _errorMessage = e.toString();
        _completeCatalogLoad();
      },
    );
  }

  void _completeCatalogLoad() {
    _catalogReady = true;
    _isLoading = false;
    _applyFilters();
    _notifyAfterFrame();
  }

  void _notifyAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hasListeners) return;
      notifyListeners();
    });
  }

  bool get isLoading => _isLoading;
  /// True only while the first catalog snapshot has not arrived yet.
  /// Category/filter changes are local and must not keep the shimmer up.
  bool get isCatalogLoading => _isLoading && !_catalogReady;
  String? get errorMessage => _errorMessage;
  List<MaterialModel> get materials => _filteredMaterials;
  List<MaterialModel> get catalogMaterials => _materials;
  List<MaterialModel> get searchResults => _searchResults;
  List<MaterialModel> get recentMaterials => _recentMaterials;
  List<MaterialModel> get recentlyViewedMaterials => _recentlyViewedMaterials;
  List<CategoryModel> get categories => _categories;
  String? get categoryFilter => _categoryFilter;
  CatalogSortOption get sortOption => _sortOption;
  bool get hasCachedMaterials => _materials.isNotEmpty;

  double supplierRatingFor(String supplierId) =>
      _supplierRatings[supplierId] ?? 0.0;

  Future<void> prefetchSupplierRatings() => _loadSupplierRatings();

  int materialCountForCategory(String categoryName) {
    final normalized = categoryName.toLowerCase();
    return _materials
        .where((m) => m.category.toLowerCase() == normalized)
        .length;
  }

  /// Unique category names from company materials (no extra Firestore call).
  List<String> get materialCategoryNames {
    final names = _materials
        .map((m) => m.category.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  List<String> get uniqueCategories {
    final seen = <String>{};
    final result = <String>[];
    for (final m in _materials) {
      final cat = m.category.trim();
      if (cat.isNotEmpty && seen.add(cat)) result.add(cat);
    }
    return result;
  }

  /// Firestore categories merged with any categories present on materials.
  List<CategoryModel> get browseCategories {
    final byName = <String, CategoryModel>{};
    for (final category in _categories) {
      byName[category.name.toLowerCase()] = category;
    }
    for (final name in materialCategoryNames) {
      final key = name.toLowerCase();
      byName.putIfAbsent(
        key,
        () => CategoryModel(
          id: key,
          name: name,
          unit: '',
          brands: const [],
          grades: const [],
        ),
      );
    }
    final list = byName.values.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> loadCategoriesBrowse(String companyId) async {
    await loadMarketplace(companyId);
  }

  Future<void> loadRecentlyViewedMaterials(
    String companyId,
    List<String> materialIds,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (materialIds.isEmpty) {
        _recentlyViewedMaterials = [];
        return;
      }

      if (_materials.isEmpty) {
        final companyMaterials =
            await _materialRepo.getCompanyMaterials(companyId).first;
        if (companyMaterials.isNotEmpty) {
          _materials = companyMaterials;
        }
      }

      final linkedIds = _materials.map((m) => m.id).toSet();
      final fetched = await _materialRepo.getMaterialsByIds(materialIds);
      final byId = {for (final material in fetched) material.id: material};

      _recentlyViewedMaterials = materialIds
          .where(linkedIds.contains)
          .map((id) => byId[id])
          .whereType<MaterialModel>()
          .toList();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearRecentlyViewedDisplay() {
    _recentlyViewedMaterials = [];
    notifyListeners();
  }

  Future<void> loadHomeData(String companyId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final categoriesFuture = _materialRepo.getCategories();
      final recentFuture =
          _materialRepo.getRecentCompanyMaterials(companyId, limit: 4);

      final results = await Future.wait([
        categoriesFuture,
        recentFuture,
      ]);

      _categories = results[0] as List<CategoryModel>;
      _recentMaterials = results[1] as List<MaterialModel>;
      _watchCompanyMaterials(companyId);
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMarketplace(String companyId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (_categories.isEmpty) {
        _categories = await _materialRepo.getCategories();
      }
      _watchCompanyMaterials(companyId);
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void filterByCategory(String? category) {
    _categoryFilter = category;
    _applyFilters();
    notifyListeners();
  }

  Future<void> setSortOption(CatalogSortOption option) async {
    _sortOption = option;
    if (option == CatalogSortOption.rating) {
      await _loadSupplierRatings();
    }
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _categoryFilter = null;
    _applyFilters();
    notifyListeners();
  }

  void searchLocalMaterials(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      _searchResults = [];
    } else {
      _searchResults = _materials
          .where(
            (m) =>
                m.name.toLowerCase().contains(q) ||
                (m.brand?.toLowerCase().contains(q) ?? false) ||
                m.supplierName.toLowerCase().contains(q) ||
                m.category.toLowerCase().contains(q),
          )
          .toList();
    }
    notifyListeners();
  }

  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }

  Future<void> _loadSupplierRatings() async {
    final supplierIds = _materials.map((m) => m.supplierId).toSet();
    final missing = supplierIds.where((id) => !_supplierRatings.containsKey(id));
    await Future.wait(
      missing.map((id) async {
        _supplierRatings[id] = await _materialRepo.getSupplierAverageRating(id);
      }),
    );
  }

  void _applyFilters() {
    var results = List<MaterialModel>.from(_materials);

    if (_categoryFilter != null && _categoryFilter!.isNotEmpty) {
      results = results
          .where((m) => m.category.toLowerCase() == _categoryFilter!.toLowerCase())
          .toList();
    }

    switch (_sortOption) {
      case CatalogSortOption.priceAsc:
        results.sort((a, b) => a.pricePerUnit.compareTo(b.pricePerUnit));
      case CatalogSortOption.priceDesc:
        results.sort((a, b) => b.pricePerUnit.compareTo(a.pricePerUnit));
      case CatalogSortOption.rating:
        results.sort((a, b) {
          final ra = _supplierRatings[a.supplierId] ?? 0.0;
          final rb = _supplierRatings[b.supplierId] ?? 0.0;
          final ratingCompare = rb.compareTo(ra);
          if (ratingCompare != 0) return ratingCompare;
          return a.pricePerUnit.compareTo(b.pricePerUnit);
        });
      case CatalogSortOption.newest:
        results.sort((a, b) {
          final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });
    }

    _filteredMaterials = results;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
