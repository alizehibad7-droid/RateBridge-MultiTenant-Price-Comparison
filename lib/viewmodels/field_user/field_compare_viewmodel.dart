import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/material_listing.dart';
import '../../repositories/material_repository.dart';
import '../../services/firestore_service.dart';

enum CompareSortOption { price, rating }

/// Supplier comparison with price anomaly detection.
class FieldCompareViewModel extends ChangeNotifier {
  final MaterialRepository _materialRepo;
  final FirestoreService _firestore;
  final FirebaseAuth _auth;

  bool _isLoading = false;
  bool _isAiLoading = false;
  String? _errorMessage;
  List<MaterialListing> _compareResults = [];
  String? _materialName;
  CompareSortOption _sortBy = CompareSortOption.price;
  String? _cityFilter;
  String? _aiSummary;
  final Map<String, String> _aiLines = {};
  int _aiGeneration = 0;

  FieldCompareViewModel(this._materialRepo, this._firestore, {FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<MaterialListing> get results => displayResults;
  List<MaterialListing> get rawResults => _compareResults;
  String? get materialName => _materialName;
  CompareSortOption get sortBy => _sortBy;
  String? get cityFilter => _cityFilter;
  bool get showAiCard =>
      (_aiSummary != null && _aiSummary!.isNotEmpty) || _isAiLoading;
  bool get isAiLoading => _isAiLoading;
  String? get aiSummary => _aiSummary;
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

  String? insightLineFor(MaterialListing listing) {
    final fromAi = _aiLines[listing.id] ?? _aiLines[listing.supplierId];
    if (fromAi != null && fromAi.trim().isNotEmpty) return fromAi.trim();
    if (listing.isBestValue) {
      return 'Best value: lowest price among non-outlier listings.';
    }
    if (listing.isAnomaly) {
      return 'Priced 15%+ above the average — confirm quality and terms.';
    }
    return null;
  }

  Future<void> loadComparison(
    String companyId,
    String materialName, {
    String? category,
    String? qualityGrade,
    String? unit,
  }) async {
    final trimmedName = materialName.trim();
    _isLoading = true;
    _errorMessage = null;
    _compareResults = [];
    _materialName = trimmedName;
    _cityFilter = null;
    _aiSummary = null;
    _aiLines.clear();
    _isAiLoading = false;
    _aiGeneration++;
    notifyListeners();

    try {
      final hasCategory = category != null && category.trim().isNotEmpty;
      final listings = trimmedName.isEmpty && !hasCategory
          ? <MaterialListing>[]
          : await _materialRepo.getCompareListingsForMaterial(
              companyId,
              trimmedName.isEmpty ? (category ?? '') : trimmedName,
              category: category,
              qualityGrade: qualityGrade,
              unit: unit,
            );
      _compareResults = _applyAnomalyAndBestValue(listings);
      _requestAiInsight();
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

  Future<void> _requestAiInsight() async {
    final gen = ++_aiGeneration;
    if (_compareResults.length < 2) {
      _aiSummary = null;
      _isAiLoading = false;
      notifyListeners();
      return;
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      debugPrint('Compare AI skipped: user is signed out');
      return;
    }

    _isAiLoading = true;
    notifyListeners();

    final rows = _compareResults.map((listing) {
      final flag = listing.isBestValue
          ? 'BEST_VALUE'
          : listing.isAnomaly
              ? 'ANOMALY'
              : 'OK';
      return '- id=${listing.id} supplier=${listing.supplierName} '
          'pricePKR=${listing.pricePerUnit.toStringAsFixed(0)}/${listing.unit} '
          'rating=${listing.supplierRating.toStringAsFixed(1)} '
          'city=${listing.city ?? '-'} flag=$flag';
    }).join('\n');

    final prompt = '''
You are RateBridge Assistant for a Pakistan construction-materials buyer.

Material: ${_materialName ?? 'material'}
Compared listings:
$rows

Respond with JSON only (no markdown):
{"summary":"2 short sentences on who to pick and why","lines":{"LISTING_ID":"max 12 words"}}
Use the listing id values from the rows as keys. Cover BEST_VALUE and ANOMALY listings at minimum.
''';

    try {
      final text = await _firestore.generateAiText(uid: uid, prompt: prompt);
      if (gen != _aiGeneration) return;
      _applyAiResponse(text);
      debugPrint('Compare AI complete summary=${_aiSummary != null}');
    } catch (e) {
      debugPrint('Compare AI failed: $e');
      if (gen != _aiGeneration) return;
      _aiSummary = null;
      _aiLines.clear();
    } finally {
      if (gen == _aiGeneration) {
        _isAiLoading = false;
        notifyListeners();
      }
    }
  }

  void _applyAiResponse(String text) {
    _aiSummary = null;
    _aiLines.clear();

    final parsed = _tryJsonObject(text);
    final rawSummary = parsed?['summary']?.toString();
    final summary = _cleanAiSummaryText(
      (rawSummary != null && rawSummary.trim().isNotEmpty)
          ? rawSummary
          : _extractSummaryField(text),
    );
    if (summary == null) {
      debugPrint('Compare AI: could not extract summary; hiding banner');
      return;
    }
    _aiSummary = summary;

    final lines = parsed?['lines'];
    if (lines is Map) {
      lines.forEach((key, value) {
        final id = key.toString().trim();
        final line = _cleanAiSummaryText(value.toString());
        if (id.isNotEmpty && line != null) _aiLines[id] = line;
      });
    }
  }

  /// Strips markdown fences / raw JSON syntax; returns null if unusable.
  String? _cleanAiSummaryText(String? value) {
    if (value == null) return null;
    var text = value.trim();
    if (text.isEmpty) return null;

    text = _stripMarkdownFences(text);
    if (text.isEmpty) return null;

    // Reject anything that still looks like a JSON payload or fence.
    if (text.startsWith('{') ||
        text.startsWith('[') ||
        text.contains('```') ||
        RegExp(r'"summary"\s*:').hasMatch(text)) {
      return null;
    }

    // Drop wrapping quotes the model sometimes leaves on the string value.
    if ((text.startsWith('"') && text.endsWith('"')) ||
        (text.startsWith("'") && text.endsWith("'"))) {
      text = text.substring(1, text.length - 1).trim();
    }
    return text.isEmpty ? null : text;
  }

  String _stripMarkdownFences(String text) {
    var trimmed = text.trim();
    final fence = RegExp(
      r'^```(?:json|JSON)?\s*\n?([\s\S]*?)\n?```\s*$',
    );
    final match = fence.firstMatch(trimmed);
    if (match != null) {
      return match.group(1)?.trim() ?? trimmed;
    }
    return trimmed
        .replaceAll(RegExp(r'```(?:json|JSON)?'), '')
        .replaceAll('```', '')
        .trim();
  }

  /// Last-resort pull of the "summary" string when full JSON decode fails.
  String? _extractSummaryField(String text) {
    final cleaned = _stripMarkdownFences(text);
    final match = RegExp(
      r'"summary"\s*:\s*"((?:[^"\\]|\\.)*)"',
    ).firstMatch(cleaned);
    if (match == null) return null;
    try {
      return jsonDecode('"${match.group(1)}"') as String?;
    } catch (_) {
      return match.group(1)
          ?.replaceAll(r'\"', '"')
          .replaceAll(r'\n', ' ')
          .trim();
    }
  }

  Map<String, dynamic>? _tryJsonObject(String text) {
    final stripped = _stripMarkdownFences(text);
    final start = stripped.indexOf('{');
    final end = stripped.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(stripped.substring(start, end + 1));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return null;
    } catch (_) {
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

enum CompareBadgeType { none, bestValue, anomaly }
