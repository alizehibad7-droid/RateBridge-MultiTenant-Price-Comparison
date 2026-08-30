import 'package:flutter/material.dart';
import '../models/supplier_compare_model.dart';
import '../models/price_history_model.dart';
import '../services/cloud_function_service.dart';

class AiViewModel extends ChangeNotifier {
  final CloudFunctionService _cloudFunctions;

  AiViewModel(this._cloudFunctions);

  String? _result;
  bool _isLoading = false;
  String? _error;

  String? get result => _result;
  bool get isLoading => _isLoading;
  bool get isAnalyzing => _isLoading;
  String? get error => _error;
  String get statusFeedback => _error ?? _result ?? "AI Engine ready for analysis.";

  void _setLoading() {
    _isLoading = true;
    _result = null;
    _error = null;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  void clearResult() {
    _result = null;
    _error = null;
    notifyListeners();
  }

  Future<void> runMarketAnalysis(String scenario) async {
    _setLoading();
    try {
      final response = await _cloudFunctions.callFunction('generateAiText', {
        'prompt': "Analyze the following construction material market scenario and provide a forecast: $scenario"
      });
      _result = response['text'];
    } catch (e) {
      _setError("Market analysis failed: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> runDetailedBidAnalysis({
    required String city,
    required List<String> materialsNeeded,
    required Map<String, dynamic> bidPrice,
  }) async {
    _setLoading();
    try {
      final response = await _cloudFunctions.callFunction('generateAiText', {
        'prompt': "Evaluate construction bid in $city. Materials: ${materialsNeeded.join(', ')}. Price details: $bidPrice. Is this bid competitive?"
      });
      _result = response['text'];
    } catch (e) {
      _setError("Bid analysis failed: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getSupplierRecommendation(
    List<SupplierCompareModel> suppliers,
    String query,
    String locale,
  ) async {
    _setLoading();
    try {
      final supplierData = suppliers.map((s) => "${s.businessName} (Rating: ${s.rating}, Price: ${s.price})").join(", ");
      final response = await _cloudFunctions.callFunction('generateAiText', {
        'prompt': "Based on these suppliers: [$supplierData], recommend the best fit for: $query. Language: $locale"
      });
      _result = response['text'];
    } catch (e) {
      _setError('AI recommendation failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getPriceTrendInsight(
    List<PriceHistoryModel> history,
    String materialName,
    String locale,
  ) async {
    _setLoading();
    try {
      final prices = history.map((h) => "${h.timestamp}: ${h.price}").join(", ");
      final response = await _cloudFunctions.callFunction('generateAiText', {
        'prompt': "Analyze price trends for $materialName based on this history: [$prices]. Language: $locale"
      });
      _result = response['text'];
    } catch (e) {
      _setError('AI insight failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
