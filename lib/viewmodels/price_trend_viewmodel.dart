// MVVM: ViewModel — business logic only
import 'package:flutter/material.dart';
import '../models/price_history_model.dart';
import '../repositories/price_history_repository.dart';

class PriceTrendViewModel extends ChangeNotifier {
  final PriceHistoryRepository _priceHistoryRepo;
  
  String _selectedRange = '1M';
  List<PriceHistoryModel> _history = [];
  bool _isLoading = false;

  PriceTrendViewModel(this._priceHistoryRepo);

  String get selectedRange => _selectedRange;
  List<PriceHistoryModel> get history => _history;
  bool get isLoading => _isLoading;
  String? get aiInsight => null;
  bool get isAiLoading => false;

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
    // AI feature removed
    return;
  }
}
