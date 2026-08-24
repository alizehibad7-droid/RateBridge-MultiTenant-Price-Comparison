// MVVM: Service — external API wrapper only
import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/firestore_paths.dart';
import '../models/voice_intent_model.dart';
import '../models/price_history_model.dart';
import '../models/supplier_compare_model.dart';
import '../utils/app_exception.dart';

class GeminiService {
  static const String _baseUrl =
    'https://api.groq.com/openai/v1/chat/completions';
  final String _groqKey = const String.fromEnvironment('GROQ_API_KEY');
  final String _geminiKey = const String.fromEnvironment('GEMINI_API_KEY');
  final http.Client _client;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  GeminiService({
    http.Client? client,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _client = client ?? http.Client(),
        _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // Rate limit: rolling 1-minute window
  int _requestCount = 0;
  DateTime _windowStart = DateTime.now();
  static const int _maxRequestsPerMinute = 14;

  bool _checkRateLimit() {
    final now = DateTime.now();
    if (now.difference(_windowStart).inMinutes >= 1) {
      _windowStart = now;
      _requestCount = 0;
    }
    if (_requestCount >= _maxRequestsPerMinute) return false;
    _requestCount++;
    return true;
  }

  String _asText(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  Future<String> _callGemini(String prompt) async {
    if (!_checkRateLimit()) {
      return 'AI recommendations temporarily unavailable. Please try again in a minute.';
    }
    if (_groqKey.isNotEmpty) {
      try {
        return await _callGroq(prompt);
      } catch (e) {
        debugPrint('Groq path failed, using Vertex job: $e');
      }
    }
    if (_geminiKey.isNotEmpty) {
      try {
        return await _callGeminiApi(prompt);
      } catch (e) {
        debugPrint('Gemini API key path failed, using Vertex job: $e');
      }
    }
    return _callFirestoreJob(prompt);
  }

  Future<String> _callFirestoreJob(String prompt) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw AppException('Sign in required for AI.');
    }

    final ref = _db.collection(FirestorePaths.aiJobsCol).doc();
    await ref.set({
      'uid': uid,
      'prompt': prompt,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    final completer = Completer<String>();
    late final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>> sub;
    sub = ref.snapshots().listen((snap) {
      final data = snap.data();
      if (data == null) return;
      final status = _asText(data['status']);
      if (status == 'complete') {
        if (!completer.isCompleted) {
          completer.complete(_asText(data['text']).trim());
        }
        sub.cancel();
      } else if (status == 'error') {
        if (!completer.isCompleted) {
          completer.completeError(
            AppException(_asText(data['error']).isEmpty
                ? 'AI request failed.'
                : _asText(data['error'])),
          );
        }
        sub.cancel();
      }
    }, onError: (Object error) {
      if (!completer.isCompleted) {
        completer.completeError(AppException('AI request failed.'));
      }
      sub.cancel();
    });

    try {
      return await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          sub.cancel();
          throw AppException('AI request timed out. Please try again.');
        },
      );
    } catch (e) {
      await sub.cancel();
      rethrow;
    }
  }

  Future<String> _callGeminiApi(String prompt) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=$_geminiKey',
    );
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
            ],
          }
        ],
        'generationConfig': {
          'maxOutputTokens': 500,
          'temperature': 0.3,
        },
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>? ?? [];
      if (candidates.isEmpty) {
        throw AppException('AI returned an empty response.');
      }
      final content = candidates.first['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List<dynamic>? ?? [];
      final text = parts
          .map((part) => (part as Map<String, dynamic>)['text'] as String? ?? '')
          .join()
          .trim();
      if (text.isEmpty) {
        throw AppException('AI returned an empty response.');
      }
      return text;
    } else if (response.statusCode == 429) {
      throw AppException('AI temporarily unavailable due to rate limiting.');
    } else {
      throw AppException('Gemini API error: ${response.statusCode}');
    }
  }

  Future<String> _callGroq(String prompt) async {
    final response = await _client.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_groqKey',
      },
      body: jsonEncode({
        'model': 'groq/compound-mini',
        'max_tokens': 500,
        'temperature': 0.3,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final choices = data is Map ? data['choices'] : null;
      final first = (choices is List && choices.isNotEmpty) ? choices[0] : null;
      final message = first is Map ? first['message'] : null;
      final messageMap = message is Map ? message : const <String, dynamic>{};
      var content = _asText(messageMap['content']).trim();
      if (content.isEmpty) {
        content = _asText(messageMap['reasoning']).trim();
      }
      if (content.isEmpty) {
        throw AppException('AI returned an empty response.');
      }
      return content;
    } else if (response.statusCode == 429) {
      return 'AI temporarily unavailable due to rate limiting. Please try again shortly.';
    } else {
      throw AppException('Gemini API error: ${response.statusCode}');
    }
  }

  Future<String> getSupplierRecommendation(
    List<SupplierCompareModel> suppliers,
    String query,
    {required String locale, bool inlineBrief = false}
  ) async {
    final suppliersJson = jsonEncode(suppliers.map((s) => {
      'name': s.businessName,
      'price': s.price,
      'rating': s.rating,
      'city': s.city,
      'isVerified': s.isVerified,
      'isPriceFlagged': s.isAnomalyFlagged,
    }).toList());
    final prompt = inlineBrief
        ? '''You are a procurement assistant for a Pakistan construction company.
Material: $query.
Suppliers: $suppliersJson.
Focus on the best-value supplier (lowest price among non-flagged options).
Return ONE short sentence, maximum 12 words, italic-friendly tone.
Use a middle dot (·) to join two short phrases if helpful.
Example: Best price this month · stable supply record
Respond in $locale. No quotes, labels, or markdown. Plain text only.'''
        : '''You are a procurement assistant for a Pakistan construction company.
Material: $query.
Suppliers available: $suppliersJson.
Recommend the best supplier in 1-2 sentences considering price, rating, and city.
Respond in $locale language. Use only the provided data. Be concise.''';
    return _callGemini(prompt);
  }

  Future<String> getPriceTrendInsight(
    List<PriceHistoryModel> history,
    String materialName,
    {required String locale}
  ) async {
    if (history.length < 3) {
      return 'Insufficient price history for AI analysis. At least 3 months of data required.';
    }
    final historyJson = jsonEncode(history.map((h) => {
      'price': h.price,
      'date': h.timestamp.toIso8601String().substring(0, 10),
    }).toList());
    final prompt = '''Analyze this price history for construction material "$materialName" in Pakistan: $historyJson.
Give a buy-now or wait advisory in at most 2 short sentences.
Mention trend direction (rising/falling/stable).
Respond in $locale. Plain text only — no title, labels, or markdown.''';
    return _callGemini(prompt);
  }

  Future<String> getHomeMarketGreeting(
    List<Map<String, dynamic>> categoryPrices,
    {required String locale}
  ) async {
    final dataJson = jsonEncode(categoryPrices);
    final prompt = '''You summarize construction material price movements for a Pakistan field buyer.
Category price data (PKR): $dataJson.
Return ONE line only, maximum 10 words, with a leading trend emoji per category mentioned.
Format example: 📈 Steel prices rising this week · Cement stable
Respond in $locale. Plain text only — no labels or markdown.''';
    return _callGemini(prompt);
  }

  Future<String> getMarketAnalysis(String scenario) async {
    final prompt = '''You are a Pakistani construction market analyst.
Scenario: $scenario.
Provide a professional market analysis and forecasting advisory.
Include:
1. Expected Trend (rising/falling/volatile).
2. Key drivers (e.g. fuel, currency, logistics).
3. Procurement recommendation.
Keep it under 150 words and be professional.''';
    return _callGemini(prompt);
  }

  Future<VoiceIntentModel> parseVoiceIntent(String transcript) async {
    final prompt = '''Extract structured data from this construction material search query: "$transcript".
Return ONLY valid JSON with exactly these fields:
{"material": "string or null", "action": "compare|order|trend|navigate|call", "filters": {"sort": "string or null", "city": "string or null", "priceMax": number_or_null}, "quantity": number_or_null}
No markdown. No explanation. JSON only.''';
    final result = await _callGemini(prompt);
    try {
      final cleanResult = result.replaceAll(RegExp(r'```json|```'), '').trim();
      final Map<String,dynamic> json = jsonDecode(cleanResult);
      return VoiceIntentModel.fromMap(json);
    } catch(e) {
      return VoiceIntentModel(
        material: transcript,
        action: 'compare',
        filters: {},
        quantity: null,
      );
    }
  }

  Future<String> askAssistant(
    String userQuestion,
    String screenName,
    Map<String, dynamic> screenContext,
  ) async {
    final contextJson = jsonEncode(screenContext);
    final prompt = '''You are the RateBridge AI Assistant, helping a 
field user of a Pakistan construction material procurement app.

The user is currently on the "$screenName" screen.
Screen context data: $contextJson

User question: "$userQuestion"

Rules:
- Answer ONLY using the screen context data provided above when 
  the question relates to prices, suppliers, or trends.
- If the question is about how to use the RateBridge app (general 
  app usage, not data), answer using general knowledge of a 
  construction material comparison and ordering app.
- Keep your answer under 60 words.
- Be direct and helpful, no greetings, no markdown, plain text only.
- If you don't have enough data to answer, say so honestly in 
  one short sentence.''';

    return _callGemini(prompt);
  }
}
