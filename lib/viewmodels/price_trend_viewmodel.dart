// MVVM: ViewModel — business logic only
import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../models/price_history_model.dart';
import '../repositories/price_history_repository.dart';

class PriceTrendViewModel extends ChangeNotifier {
  final PriceHistoryRepository _priceHistoryRepo;
  final GeminiService _geminiService;
  
  String _selectedRange = '1M';
  List<PriceHistoryModel> _history = [];
  bool _isLoading = false;
  String? _aiInsight;
  bool _isAiLoading = false;

  PriceTrendViewModel(this._priceHistoryRepo, this._geminiService);

  String get selectedRange => _selectedRange;
  List<PriceHistoryModel> get history => _history;
  bool get isLoading => _isLoading;
  String? get aiInsight => _aiInsight;
  bool get isAiLoading => _isAiLoading;

  void setRange(String range) {
    _selectedRange = range;
    // loadHistory logic based on range
  }

  Future<void> loadHistory(String matId, String companyId) async {
    _isLoading = true;
    notifyListeners();
    
    _priceHistoryRepo.watchPriceHistory(matId, companyId, null).listen((data) {
      _history = data;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> getAiInsight(String materialName, String locale) async {
    if (_history.length < 3) return;
    
    _isAiLoading = true;
    _aiInsight = null;
    notifyListeners();
    
    try {
      _aiInsight = await _geminiService.getPriceTrendInsight(_history, materialName, locale: locale);
    } catch (e) {
      _aiInsight = "AI Analysis unavailable: $e";
    } finally {
      _isAiLoading = false;
      notifyListeners();
    }
  }
}
