import 'package:flutter/material.dart';
import '../../models/material_listing.dart';
import '../../models/supplier_compare_model.dart';
import '../../repositories/material_repository.dart';
import '../../services/gemini_service.dart';

enum CompareSortOption { price, rating }

/// Supplier comparison with price anomaly detection and AI insights.
class FieldCompareViewModel extends ChangeNotifier {
  final MaterialRepository _materialRepo;
  final GeminiService _geminiService;

  bool _isLoading = false;
  String? _errorMessage;
  List<MaterialListing> _compareResults = [];
  String? _materialName;
  CompareSortOption _sortBy = CompareSortOption.price;
  String? _cityFilter;

  String? _aiRecommendation;
  bool _isAiLoading = false;

  FieldCompareViewModel(this._materialRepo, this._geminiService);

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<MaterialListing> get results => displayResults;
  List<MaterialListing> get rawResults => _compareResults;
  String? get materialName => _materialName;
  CompareSortOption get sortBy => _sortBy;
  String? get cityFilter => _cityFilter;
  String? get aiRecommendation => _aiRecommendation;
  bool get isAiLoading => _isAiLoading;
  bool get showAiCard =>
      _aiRecommendation != null && _aiRecommendation!.isNotEmpty;
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
    _aiRecommendation = null;
    _isAiLoading = false;
    notifyListeners();

    try {
      final listings = trimmedName.isEmpty
          ? <MaterialListing>[]
          : await _materialRepo.getCompareListingsForMaterial(
              companyId,
              trimmedName,
            );
      _compareResults = _applyAnomalyAndBestValue(listings);
      if (_compareResults.isNotEmpty) {
        _loadAiRecommendation();
      }
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

  Future<void> _loadAiRecommendation() async {
    if (_compareResults.isEmpty || _materialName == null) return;

    _isAiLoading = true;
    _aiRecommendation = null;
    notifyListeners();

    try {
      final supplierPayload = _compareResults
          .map(
            (listing) => SupplierCompareModel(
              supplierUid: listing.supplierId,
              businessName: listing.supplierName,
              price: listing.pricePerUnit,
              rating: listing.supplierRating,
              reviewCount: listing.reviewCount,
              city: listing.city ?? '',
              isVerified: false,
              isAnomalyFlagged: listing.isAnomaly,
              materialId: listing.id,
              materialName: listing.materialName,
              unit: listing.unit,
              category: listing.category,
              phone: listing.phone ?? '',
              priceUpdatedAt: listing.priceUpdatedAt,
            ),
          )
          .toList();

      final result = await _geminiService.getSupplierRecommendation(
        supplierPayload,
        _materialName!,
        locale: 'en',
        inlineBrief: true,
      );
      final trimmed = result.trim();
      if (trimmed.isNotEmpty &&
          !trimmed.toLowerCase().contains('temporarily unavailable') &&
          !trimmed.toLowerCase().contains('rate limit')) {
        _aiRecommendation = _limitWords(trimmed, 12);
      }
    } catch (_) {
      _aiRecommendation = null;
    } finally {
      _isAiLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  static String _limitWords(String text, int maxWords) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final list = words.toList();
    if (list.length <= maxWords) return text;
    return list.take(maxWords).join(' ');
  }
}

enum CompareBadgeType { none, bestValue, anomaly }
