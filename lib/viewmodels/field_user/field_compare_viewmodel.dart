import 'package:flutter/material.dart';
import '../../models/material_listing.dart';
import '../../repositories/material_repository.dart';

enum CompareSortOption { price, rating }

/// Supplier comparison with price anomaly detection.
class FieldCompareViewModel extends ChangeNotifier {
  final MaterialRepository _materialRepo;

  bool _isLoading = false;
  String? _errorMessage;
  List<MaterialListing> _compareResults = [];
  String? _materialName;
  CompareSortOption _sortBy = CompareSortOption.price;
  String? _cityFilter;

  FieldCompareViewModel(this._materialRepo);

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<MaterialListing> get results => displayResults;
  List<MaterialListing> get rawResults => _compareResults;
  String? get materialName => _materialName;
  CompareSortOption get sortBy => _sortBy;
  String? get cityFilter => _cityFilter;
  bool get showAiCard => false;
  bool get hasCityFilter => _cityFilter != null && _cityFilter!.isNotEmpty;

  List<String> get availableCities {
    final cities = _compareResults
        .map((r) => (r.city ?? '').trim())
        .where((city) => city.isNotEmpty)
        .toSet()
        .toList();
    cities.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return cities;
  }

  double? get bestPrice => _compareResults.isNotEmpty
      ? _compareResults.map((r) => r.pricePerUnit).reduce((a, b) => a < b ? a : b)
      : null;

  List<MaterialListing> get displayResults {
    var list = List<MaterialListing>.from(_compareResults);
    if (_cityFilter != null && _cityFilter!.isNotEmpty) {
      list = list.where((r) => r.city == _cityFilter).toList();
    }
    if (_sortBy == CompareSortOption.price) {
      list.sort((a, b) => a.pricePerUnit.compareTo(b.pricePerUnit));
    } else {
      list.sort((a, b) {
        final byRating = b.supplierRating.compareTo(a.supplierRating);
        if (byRating != 0) return byRating;
        return a.pricePerUnit.compareTo(b.pricePerUnit);
      });
    }
    return list;
  }

  MaterialListing? get bestValueSupplier {
    try {
      return _compareResults.firstWhere((r) => r.isBestValue);
    } catch (_) {
      return null;
    }
  }

  CompareBadgeType badgeFor(MaterialListing listing) {
    if (listing.isAnomaly) return CompareBadgeType.anomaly;
    if (listing.isBestValue) return CompareBadgeType.bestValue;
    return CompareBadgeType.none;
  }

  Future<void> loadComparison(String companyId, String materialName) async {
    final trimmedName = materialName.trim();
    _isLoading = true;
    _errorMessage = null;
    _compareResults = [];
    _materialName = trimmedName;
    _cityFilter = null;
    notifyListeners();

    try {
      final listings = trimmedName.isEmpty
          ? <MaterialListing>[]
          : await _materialRepo.getCompareListingsForMaterial(
              companyId,
              trimmedName,
            );
      _compareResults = _applyAnomalyAndBestValue(listings);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Backward-compatible alias.
  Future<void> loadCompareRates(String companyId, String materialName) =>
      loadComparison(companyId, materialName);

  List<MaterialListing> _applyAnomalyAndBestValue(
    List<MaterialListing> listings,
  ) {
    if (listings.isEmpty) return [];

    final avgPrice = listings
            .map((listing) => listing.pricePerUnit)
            .reduce((a, b) => a + b) /
        listings.length;

    final flagged = listings
        .map(
          (listing) => listing.copyWith(
            isAnomaly: listing.pricePerUnit > avgPrice * 1.15,
            isBestValue: false,
          ),
        )
        .toList();

    final nonAnomalous =
        flagged.where((listing) => !listing.isAnomaly).toList();
    if (nonAnomalous.isEmpty) return flagged;

    nonAnomalous.sort((a, b) => a.pricePerUnit.compareTo(b.pricePerUnit));
    final bestId = nonAnomalous.first.id;
    final bestSupplierId = nonAnomalous.first.supplierId;

    return flagged
        .map(
          (listing) => listing.id == bestId &&
                  listing.supplierId == bestSupplierId &&
                  !listing.isAnomaly
              ? listing.copyWith(isBestValue: true)
              : listing,
        )
        .toList()
      ..sort((a, b) => a.pricePerUnit.compareTo(b.pricePerUnit));
  }

  void setSortBy(CompareSortOption option) {
    if (_sortBy == option) return;
    _sortBy = option;
    notifyListeners();
  }

  void setCityFilter(String? city) {
    if (_cityFilter == city) return;
    _cityFilter = city;
    notifyListeners();
  }

  void clearCityFilter() => setCityFilter(null);

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

enum CompareBadgeType { none, bestValue, anomaly }
