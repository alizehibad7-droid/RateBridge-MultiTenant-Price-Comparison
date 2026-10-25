import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';
import '../utils/app_exception.dart';

enum StripePayOutcome {
  /// Payment Sheet finished successfully (mobile).
  completed,
  /// Browser redirected to Stripe Checkout (web). Activation via webhook/job.
  redirected,
}

/// Starts Stripe payments via Firestore [stripe_jobs] (same pattern as AI).
/// After Checkout success, [claimSubscriptionActivation] unlocks the plan via
/// Admin SDK ([stripe_activate_jobs]) so client permission issues cannot block it.
class StripeService {
  static const _prefsPlanKey = 'pending_stripe_plan';
  static const _prefsCompanyKey = 'pending_stripe_company';
  static const _prefsAmountKey = 'pending_stripe_amount';
  static const _prefsCommissionTxKey = 'pending_stripe_commission_txs';

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  StripeService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  Future<StripePayOutcome> payWithStripe({
    required String type, // "subscription" or "commission"
    String? plan,
    String? companyId,
    int? amountPKR,
    List<String>? transactionIds,
  }) async {
    if (AppConstants.defenseDemoMode) {
      throw AppException(
        'Stripe needs Firebase Blaze billing (not available for this demo). '
        'Subscription UI and plans are ready — live checkout after Blaze is enabled.',
        'unavailable',
      );
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw AppException('Please sign in again and retry.', 'unauthenticated');
    }

    if (kIsWeb) {
      if (type == 'subscription' &&
          (companyId == null || companyId.isEmpty)) {
        throw AppException(
          'Company ID missing. Please sign out, sign in again, and retry.',
        );
      }
      if (type == 'subscription' && (plan == null || plan.isEmpty)) {
        throw AppException('Plan is required for subscription payment.');
      }

      if (type == 'subscription') {
        await _savePendingSubscription(
          plan: plan!,
          companyId: companyId!,
          amountPKR: amountPKR,
        );
      } else if (type == 'commission' &&
          transactionIds != null &&
          transactionIds.isNotEmpty) {
        await _savePendingCommissionTxIds(transactionIds);
      }

      final url = await _runJob(
        collection: 'stripe_jobs',
        uid: uid,
        payload: {
          'mode': 'checkout',
          'type': type,
          if (plan != null) 'plan': plan,
          if (companyId != null && companyId.isNotEmpty) 'companyId': companyId,
          if (amountPKR != null) 'amountPKR': amountPKR,
          if (transactionIds != null) 'transactionIds': transactionIds,
          'successUrl': _webReturnUrl(
            path: type == 'subscription'
                ? '/ceo/subscription'
                : '/supplier/earnings',
            status: 'success',
            plan: plan,
          ),
          'cancelUrl': _webReturnUrl(
            path: type == 'subscription'
                ? '/ceo/subscription'
                : '/supplier/earnings',
            status: 'cancel',
            plan: plan,
          ),
        },
        resultKey: 'url',
      );

      final ok = await launchUrl(
        Uri.parse(url),
        webOnlyWindowName: '_self',
      );
      if (!ok) {
        throw AppException('Could not open Stripe Checkout.');
      }
      return StripePayOutcome.redirected;
    }

    final clientSecret = await _runJob(
      collection: 'stripe_jobs',
      uid: uid,
      payload: {
        'mode': 'payment_sheet',
        'type': type,
        if (plan != null) 'plan': plan,
        if (companyId != null && companyId.isNotEmpty) 'companyId': companyId,
        if (amountPKR != null) 'amountPKR': amountPKR,
        if (transactionIds != null) 'transactionIds': transactionIds,
      },
      resultKey: 'clientSecret',
    );

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'RateBridge',
        ),
      );
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      debugPrint(
        'Stripe error: ${e.error.localizedMessage} code=${e.error.code}',
      );
      if (e.error.code == FailureCode.Canceled) {
        throw AppException('Payment cancelled.', 'canceled');
      }
      throw AppException(e.error.localizedMessage ?? 'Payment failed');
    }

    return StripePayOutcome.completed;
  }

  /// Unlocks a paid plan after Checkout return (Admin SDK via Cloud Function).
  /// When [checkoutSessionId] is provided, the server verifies the session is paid.
  Future<void> claimSubscriptionActivation({
    required String companyId,
    required String plan,
    int? amountPKR,
    String? checkoutSessionId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw AppException('Please sign in again and retry.', 'unauthenticated');
    }
    if (companyId.isEmpty || plan.isEmpty || plan == 'free') {
      throw AppException('Invalid activation request.');
    }

    debugPrint(
      'Stripe activate: companyId=$companyId plan=$plan amount=$amountPKR session=$checkoutSessionId',
    );

    await _runJob(
      collection: 'stripe_activate_jobs',
      uid: uid,
      payload: {
        'companyId': companyId,
        'plan': plan,
        if (amountPKR != null) 'amountPKR': amountPKR,
        if (checkoutSessionId != null && checkoutSessionId.isNotEmpty)
          'paymentRefId': checkoutSessionId,
      },
      resultKey: null, // completion only
    );

    await _clearPendingSubscription();
  }

  /// Settles commission txs after web Checkout return (Admin SDK).
  Future<void> claimCommissionSettlement({
    required List<String> transactionIds,
    String? checkoutSessionId,
    int? amountPKR,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw AppException('Please sign in again and retry.', 'unauthenticated');
    }
    final ids = transactionIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (ids.isEmpty) {
      throw AppException('No commission transactions to settle.');
    }

    await _runJob(
      collection: 'stripe_activate_jobs',
      uid: uid,
      payload: {
        'type': 'commission',
        'transactionIds': ids,
        if (amountPKR != null) 'amountPKR': amountPKR,
        if (checkoutSessionId != null && checkoutSessionId.isNotEmpty)
          'paymentRefId': checkoutSessionId,
      },
      resultKey: null,
    );

    await clearPendingCommissionTxIds();
  }

  Future<({String plan, String companyId, int? amountPKR})?>
      readPendingSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final plan = prefs.getString(_prefsPlanKey);
    final companyId = prefs.getString(_prefsCompanyKey);
    if (plan == null ||
        plan.isEmpty ||
        companyId == null ||
        companyId.isEmpty) {
      return null;
    }
    return (
      plan: plan,
      companyId: companyId,
      amountPKR: prefs.getInt(_prefsAmountKey),
    );
  }

  Future<List<String>> readPendingCommissionTxIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsCommissionTxKey)?.trim() ?? '';
    if (raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _savePendingSubscription({
    required String plan,
    required String companyId,
    int? amountPKR,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsPlanKey, plan);
    await prefs.setString(_prefsCompanyKey, companyId);
    if (amountPKR != null) {
      await prefs.setInt(_prefsAmountKey, amountPKR);
    } else {
      await prefs.remove(_prefsAmountKey);
    }
  }

  Future<void> _savePendingCommissionTxIds(List<String> txIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsCommissionTxKey,
      txIds.where((e) => e.trim().isNotEmpty).join(','),
    );
  }

  Future<void> clearPendingSubscription() => _clearPendingSubscription();

  Future<void> clearPendingCommissionTxIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsCommissionTxKey);
  }

  Future<void> _clearPendingSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsPlanKey);
    await prefs.remove(_prefsCompanyKey);
    await prefs.remove(_prefsAmountKey);
  }

  Future<String> _runJob({
    required String collection,
    required String uid,
    required Map<String, dynamic> payload,
    required String? resultKey,
  }) async {
    final ref = _db.collection(collection).doc();
    debugPrint('Stripe job ${ref.id} → $collection');

    await ref.set({
      'uid': uid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      ...payload,
    });

    // Wait up to 120s — Cloud Function cold starts can exceed 60s.
    // Snapshots + periodic server polls (web listeners can stall).
    DocumentSnapshot<Map<String, dynamic>> done;
    try {
      done = await _waitForJobResult(ref)
          .timeout(const Duration(seconds: 120));
    } on TimeoutException {
      done = await ref.get(const GetOptions(source: Source.server));
    }

    final data = done.data() ?? {};
    final status = data['status']?.toString() ?? 'pending';
    if (status == 'error') {
      final reason = (data['error'] as String?)?.trim();
      throw AppException(
        (reason != null && reason.isNotEmpty)
            ? reason
            : 'Payment failed. Please try again.',
      );
    }
    if (status != 'complete') {
      if (status == 'processing') {
        throw AppException(
          'Payment is still starting on the server. Please try again in a moment.',
          'deadline-exceeded',
        );
      }
      throw AppException(
        'Payment timed out before Stripe opened. Please try again.',
        'deadline-exceeded',
      );
    }

    if (resultKey == null) return '';
    final value = (data[resultKey] as String?)?.trim() ?? '';
    if (value.isEmpty) {
      throw AppException('Payment could not be started. Please try again.');
    }
    return value;
  }

  /// Resolves when the job doc reaches complete|error.
  Future<DocumentSnapshot<Map<String, dynamic>>> _waitForJobResult(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    DocumentSnapshot<Map<String, dynamic>>? result;

    bool isTerminal(DocumentSnapshot<Map<String, dynamic>> snap) {
      final status = snap.data()?['status']?.toString();
      return status == 'complete' || status == 'error';
    }

    final sub = ref.snapshots().listen((snap) {
      if (isTerminal(snap)) result = snap;
    });

    try {
      // Immediate server read in case the function already finished.
      final first = await ref.get(const GetOptions(source: Source.server));
      if (isTerminal(first)) return first;

      final deadline = DateTime.now().add(const Duration(seconds: 115));
      while (DateTime.now().isBefore(deadline)) {
        if (result != null) return result!;
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        if (result != null) return result!;
        try {
          final polled = await ref.get(const GetOptions(source: Source.server));
          if (isTerminal(polled)) return polled;
        } catch (e) {
          debugPrint('Stripe job poll skipped: $e');
        }
      }
      if (result != null) return result!;
      return await ref.get(const GetOptions(source: Source.server));
    } finally {
      await sub.cancel();
    }
  }

  String _webReturnUrl({
    required String path,
    required String status,
    String? plan,
  }) {
    final normalized = path.startsWith('/') ? path : '/$path';
    // Keep Stripe's `{CHECKOUT_SESSION_ID}` literal unencoded so Stripe can
    // replace it. Encode other values normally.
    final parts = <String>[
      'stripe=${Uri.encodeQueryComponent(status)}',
      if (plan != null && plan.isNotEmpty)
        'plan=${Uri.encodeQueryComponent(plan)}',
      'session_id={CHECKOUT_SESSION_ID}',
    ];
    final query = parts.join('&');

    // Match how the app is currently routed (hash vs path).
    final href = Uri.base.toString();
    final hashMode = href.contains('/#/') ||
        (Uri.base.fragment.isNotEmpty && Uri.base.fragment.startsWith('/'));
    if (hashMode) {
      return '${Uri.base.origin}/#$normalized?$query';
    }
    return '${Uri.base.origin}$normalized?$query';
  }
}
