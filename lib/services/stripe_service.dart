import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
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
  Future<void> claimSubscriptionActivation({
    required String companyId,
    required String plan,
    int? amountPKR,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw AppException('Please sign in again and retry.', 'unauthenticated');
    }
    if (companyId.isEmpty || plan.isEmpty || plan == 'free') {
      throw AppException('Invalid activation request.');
    }

    debugPrint(
      'Stripe activate: companyId=$companyId plan=$plan amount=$amountPKR',
    );

    await _runJob(
      collection: 'stripe_activate_jobs',
      uid: uid,
      payload: {
        'companyId': companyId,
        'plan': plan,
        if (amountPKR != null) 'amountPKR': amountPKR,
      },
      resultKey: null, // completion only
    );

    await _clearPendingSubscription();
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

  Future<void> clearPendingSubscription() => _clearPendingSubscription();

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

    final done = await ref.snapshots().firstWhere((snap) {
      final status = snap.data()?['status']?.toString();
      return status == 'complete' || status == 'error';
    }).timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        throw AppException(
          'Payment timed out. Please try again.',
          'deadline-exceeded',
        );
      },
    );

    final data = done.data() ?? {};
    if (data['status']?.toString() == 'error') {
      final reason = (data['error'] as String?)?.trim();
      throw AppException(
        (reason != null && reason.isNotEmpty)
            ? reason
            : 'Payment failed. Please try again.',
      );
    }

    if (resultKey == null) return '';
    final value = (data[resultKey] as String?)?.trim() ?? '';
    if (value.isEmpty) {
      throw AppException('Payment could not be started. Please try again.');
    }
    return value;
  }

  String _webReturnUrl({
    required String path,
    required String status,
    String? plan,
  }) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final params = <String, String>{
      'stripe': status,
      if (plan != null && plan.isNotEmpty) 'plan': plan,
    };
    final query = params.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '${Uri.base.origin}/#$normalized?$query';
  }
}
