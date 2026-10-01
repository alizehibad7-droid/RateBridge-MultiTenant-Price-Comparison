import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/firestore_service.dart';
import '../services/plan_limit_service.dart';
import '../utils/app_exception.dart';

class AiViewModel extends ChangeNotifier {
  final FirestoreService _firestore;
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  AiViewModel(this._firestore, {FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  String? _result;
  bool _isLoading = false;
  String? _error;

  String? get result => _result;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw AppException('Please sign in again and retry.', 'unauthenticated');
    }
    return uid;
  }

  Future<void> _ensureCompanyAiAccess(String uid) async {
    final user = await _firestore.getUser(uid);
    final companyId = user?.companyId.trim() ?? '';
    if (companyId.isEmpty) {
      throw AppException(
        'AI features require a company account on the Basic plan or higher.',
        'plan_required',
      );
    }
    await PlanLimitService.ensureAiAccess(_db, companyId);
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
    final uid = _requireUid();
    await _ensureCompanyAiAccess(uid);

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
    try {
      return await _runPrompt(prompt);
    } catch (e) {
      _setError(e);
      rethrow;
    }
  }
}
