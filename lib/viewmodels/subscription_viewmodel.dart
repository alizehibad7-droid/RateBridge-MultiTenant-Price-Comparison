import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../models/subscription_model.dart';
import '../services/firestore_service.dart';
import '../services/cloud_function_service.dart';

class SubscriptionViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final CloudFunctionService _cloudFunctionService = CloudFunctionService();

  bool _isLoading = false;
  String? error;
  String? successMessage;
  SubscriptionModel? _subscription;

  // --- Getters ---
  bool get isLoading => _isLoading;
  SubscriptionModel? get currentSubscription => _subscription;
  List<SubscriptionHistoryEntry> get history => _subscription?.history ?? [];

  // --- Load Subscription ---
  Future<void> loadSubscription(String companyId) async {
    if (companyId.isEmpty) return;
    _isLoading = true;
    error = null;
    notifyListeners();
    try {
      _subscription = await _firestoreService.getSubscription(companyId);
      if (_subscription == null) {
        _subscription = SubscriptionModel(
          companyId: companyId,
          plan: 'free',
          status: 'active',
        );
      }
    } catch (e) {
      error = 'Failed to load subscription: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Watch Subscription (Stream) ---
  Stream<SubscriptionModel?> watchSubscription(String companyId) {
    if (companyId.isEmpty) return Stream.value(null);
    return _firestoreService.streamSubscription(companyId).map((sub) {
      if (sub == null) {
        return SubscriptionModel(
          companyId: companyId,
          plan: 'free',
          status: 'active',
        );
      }
      _subscription = sub;
      // Note: We don't call notifyListeners() here to avoid build cycles if used in StreamBuilder
      return sub;
    });
  }

  // --- Purchase Plan ---
  Future<void> purchasePlan(String companyId, PlanDefinition plan) async {
    if (plan.id == PlanId.free) {
      await _setFreePlan(companyId);
      return;
    }

    _isLoading = true;
    error = null;
    successMessage = null;
    notifyListeners();

    try {
      // 1. Create Payment Intent via Cloud Function
      final response = await _cloudFunctionService.callFunction('createPaymentIntent', {
        'amount': plan.priceRs * 100, // Stripe expects amount in subunits (cents/paisa)
        'currency': 'pkr',
        'companyId': companyId,
        'plan': plan.planKey,
      });

      final clientSecret = response['clientSecret'];
      final paymentIntentId = response['id'];

      // 2. Initialize and Present Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'RateBridge',
          style: ThemeMode.light,
        ),
      );
      
      await Stripe.instance.presentPaymentSheet();

      // 3. Update Firestore after successful payment
      await _activateSubscription(
        companyId: companyId,
        plan: plan,
        paymentIntentId: paymentIntentId,
        adminGranted: false,
      );

      successMessage = '${plan.name} plan activated successfully!';
    } on StripeException catch (e) {
      error = e.error.code == FailureCode.Canceled
          ? 'Payment cancelled.'
          : 'Payment failed: ${e.error.localizedMessage}';
    } catch (e) {
      error = 'Something went wrong: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Admin Grant Plan ---
  Future<void> adminGrantPlan({
    required String companyId,
    required PlanDefinition plan,
    required String note,
  }) async {
    _isLoading = true;
    error = null;
    notifyListeners();
    try {
      await _activateSubscription(
        companyId: companyId,
        plan: plan,
        paymentIntentId: '',
        adminGranted: true,
        adminNote: note.trim().isEmpty ? null : note.trim(),
      );
      successMessage = '${plan.name} plan granted to company.';
    } catch (e) {
      error = 'Failed to grant plan: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Internal Helpers ---

  Future<void> _setFreePlan(String companyId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final sub = SubscriptionModel(
        companyId: companyId,
        plan: 'free',
        status: 'active',
        startedAt: DateTime.now(),
      );
      await _firestoreService.saveSubscription(sub);
      
      final historyEntry = SubscriptionHistoryEntry(
        plan: 'free',
        action: 'downgraded',
        date: DateTime.now(),
        amountPaid: 0,
      );
      await _firestoreService.updateSubscriptionHistory(companyId, historyEntry);
      
      await loadSubscription(companyId);
      successMessage = 'Switched to Free plan.';
    } catch (e) {
      error = 'Failed to update plan: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _activateSubscription({
    required String companyId,
    required PlanDefinition plan,
    required String paymentIntentId,
    required bool adminGranted,
    String? adminNote,
  }) async {
    final now = DateTime.now();
    final expiry = plan.durationDays > 0
        ? now.add(Duration(days: plan.durationDays))
        : null;

    final updatedSub = SubscriptionModel(
      companyId: companyId,
      plan: plan.planKey,
      status: adminGranted ? 'admin_granted' : 'active',
      startedAt: now,
      expiresAt: expiry,
      stripePaymentIntentId: paymentIntentId.isEmpty ? null : paymentIntentId,
      adminGranted: adminGranted,
      adminNote: adminNote,
    );

    await _firestoreService.saveSubscription(updatedSub);

    final historyEntry = SubscriptionHistoryEntry(
      plan: plan.planKey,
      action: adminGranted ? 'admin_granted' : 'purchased',
      date: now,
      amountPaid: adminGranted ? 0 : plan.priceRs,
      note: adminNote,
    );
    
    await _firestoreService.updateSubscriptionHistory(companyId, historyEntry);
    await loadSubscription(companyId);
  }

  void clearMessages() {
    error = null;
    successMessage = null;
    notifyListeners();
  }
}
