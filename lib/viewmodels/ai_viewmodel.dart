import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/price_history_model.dart';
import '../models/supplier_compare_model.dart';
import '../services/firestore_service.dart';
import '../utils/app_exception.dart';

class AiViewModel extends ChangeNotifier {
  final FirestoreService _firestore;

  AiViewModel(this._firestore);

  String? _result;
  bool _isLoading = false;
  String? _error;

  String? get result => _result;
  bool get isLoading => _isLoading;
  bool get isAnalyzing => _isLoading;
  String? get error => _error;
  String get statusFeedback =>
      _error ?? _result ?? 'AI Engine ready for analysis.';

  void _setLoading() {
    _isLoading = true;
    _result = null;
    _error = null;
    notifyListeners();
  }

  void _setError(Object error) {
    final message = error is AppException ? error.message : error.toString();
    debugPrint('AiViewModel error: $message');
    _error = message;
    _isLoading = false;
    notifyListeners();
  }

  void clearResult() {
    _result = null;
    _error = null;
    notifyListeners();
  }

  String _requireUid() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw AppException('Please sign in again and retry.', 'unauthenticated');
    }
    return uid;
  }

  String _clip(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);

  String _safeJson(Map<String, dynamic> data) {
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  Future<String> _runPrompt(String prompt) {
    return _firestore.generateAiText(uid: _requireUid(), prompt: prompt);
  }

  /// Chat assistant used by Field (and any panel that opens the assistant sheet).
  Future<String> askAssistant({
    required String question,
    required String screenName,
    Map<String, dynamic> screenData = const {},
  }) async {
    final contextBlock = _clip(_safeJson(screenData), 4000);
    final prompt = _clip(
      '''
You are RateBridge Assistant for a B2B construction-materials procurement app used in Pakistan (CEO, field users, and suppliers).

Current screen: $screenName
Screen context (JSON, may be empty):
$contextBlock

User question:
$question

Rules:
- Answer helpfully in clear, concise English.
- Explain how RateBridge features work when asked (compare prices, orders, RFQs, suppliers, marketplace).
- Do not invent live prices, order IDs, or private account data that is not in the screen context.
- If you lack data, say so and tell the user where to look in the app.
''',
      12000,
    );

    debugPrint(
      'AI assistant ask screen=$screenName questionLen=${question.length}',
    );
    return _runPrompt(prompt);
  }

  Future<void> runMarketAnalysis(String scenario) async {
    _setLoading();
    try {
      _result = await _runPrompt(
        'Analyze the following construction material market scenario and provide a forecast: $scenario',
      );
    } catch (e) {
      _setError(e);
      return;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> runDetailedBidAnalysis({
    required String city,
    required List<String> materialsNeeded,
    required Map<String, dynamic> bidPrice,
  }) async {
    _setLoading();
    try {
      _result = await _runPrompt(
        'Evaluate construction bid in $city. Materials: ${materialsNeeded.join(', ')}. Price details: $bidPrice. Is this bid competitive?',
      );
    } catch (e) {
      _setError(e);
      return;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> getSupplierRecommendation(
    List<SupplierCompareModel> suppliers,
    String query,
    String locale,
  ) async {
    _setLoading();
    try {
      final supplierData = suppliers
          .map((s) => '${s.businessName} (Rating: ${s.rating}, Price: ${s.price})')
          .join(', ');
      _result = await _runPrompt(
        'Based on these suppliers: [$supplierData], recommend the best fit for: $query. Language: $locale',
      );
    } catch (e) {
      _setError(e);
      return;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> getPriceTrendInsight(
    List<PriceHistoryModel> history,
    String materialName,
    String locale,
  ) async {
    _setLoading();
    try {
      final prices =
          history.map((h) => '${h.timestamp}: ${h.price}').join(', ');
      _result = await _runPrompt(
        'Analyze price trends for $materialName based on this history: [$prices]. Language: $locale',
      );
    } catch (e) {
      _setError(e);
      return;
    }
    _isLoading = false;
    notifyListeners();
  }
}
