// MVVM: ViewModel — business logic only
import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../models/supplier_compare_model.dart';
import '../models/price_history_model.dart';

class AiViewModel extends ChangeNotifier {
  final GeminiService _geminiService;

  AiViewModel(this._geminiService);

  String? _result;
  bool _isLoading = false;
  String? _error;

  String? get result => _result;
  bool get isLoading => _isLoading;
  bool get isAnalyzing => _isLoading;
  String? get error => _error;
  String get statusFeedback => _error ?? _result ?? "Enter forecasting parameters above to run AI modeling.";

  void _setLoading() {
    _isLoading = true;
    _result = null;
    _error = null;
    notifyListeners();
  }

  void _setResult(String result) {
    _result = result;
    _isLoading = false;
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
    if (scenario.isEmpty) {
      _setError("Please enter a scenario for analysis.");
      return;
    }
    _setLoading();
    try {
      final result = await _geminiService.getMarketAnalysis(scenario);
      _setResult(result);
    } catch (e) {
      _setError("AI Predictive Engine unavailable. Please check your connection.");
    }
  }

  Future<void> runDetailedBidAnalysis({
    required String city,
    required List<String> materialsNeeded,
    required Map<String, dynamic> bidPrice,
  }) async {
    _setLoading();
    try {
      // For demonstration, simulating a complex predictive sourcing response.
      // In production, this would call GeminiService with data-rich prompts.
      await Future.delayed(const Duration(seconds: 2));
      _setResult("Predictive modelling for $city complete. \n\nExpected Trend: High Volatility (Steel +4.5% in 3 weeks). \nFuel adjustment charges are projected to impact logistics from Hub to Karachi sites. \n\nRecommendation: Procure 60% of structural steel requirements within the next 7 days to hedge against imminent price hikes.");
    } catch (e) {
      _setError("AI Predictive Engine unavailable. Please check your connection.");
    }
  }

  Future<void> getSupplierRecommendation(
    List<SupplierCompareModel> suppliers,
    String query,
    String locale,
  ) async {
    _setLoading();
    try {
      final result = await _geminiService.getSupplierRecommendation(suppliers, query, locale: locale);
      _setResult(result);
    } catch(e) {
      _setError('AI recommendation unavailable. Please try again.');
    }
  }

  Future<void> getPriceTrendInsight(
    List<PriceHistoryModel> history,
    String materialName,
    String locale,
  ) async {
    if (history.length < 3) {
      _setError('Need at least 3 months of price data for AI insight.');
      return;
    }
    _setLoading();
    try {
      final result = await _geminiService.getPriceTrendInsight(history, materialName, locale: locale);
      _setResult(result);
    } catch(e) {
      _setError('AI insight unavailable. Please try again.');
    }
  }
}
