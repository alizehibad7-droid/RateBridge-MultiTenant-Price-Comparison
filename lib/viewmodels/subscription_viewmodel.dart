import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/subscription_model.dart';
import '../services/cloud_function_service.dart';
import '../services/firestore_service.dart';

class SubscriptionViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final FirebaseFirestore _db;

  SubscriptionViewModel(
    this._firestoreService,
    CloudFunctionService _, {
    FirebaseFirestore? firestore,
  })  : _db = firestore ?? FirebaseFirestore.instance;

  bool _isLoading = false;
  String? error;
  String? successMessage;
  SubscriptionModel? _subscription;

  bool get isLoading => _isLoading;
  SubscriptionModel? get currentSubscription => _subscription;
  List<SubscriptionHistoryEntry> get history => _subscription?.history ?? [];

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

  Stream<SubscriptionModel?> watchSubscription(String companyId) {
    if (companyId.isEmpty) return Stream.value(null);
    return _firestoreService.streamSubscription(companyId).map((sub) {
      if (sub == null) {
        final defaultSub = SubscriptionModel(
          companyId: companyId,
          plan: 'free',
          status: 'active',
        );
        _subscription = defaultSub;
        return defaultSub;
      }
      _subscription = sub;
      return sub;
    });
  }

  Future<void> adminGrantPlan({
    required String companyId,
    required PlanDefinition plan,
    required String note,
  }) async {
    _isLoading = true;
    error = null;
    notifyListeners();
    try {
      await activateSubscription(
        companyId: companyId,
        plan: plan,
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

  Future<void> activateSubscription({
    required String companyId,
    required PlanDefinition plan,
    required bool adminGranted,
    String? adminNote,
    int? amountPaid,
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
      adminGranted: adminGranted,
      adminNote: adminNote,
    );

    // 1. Save to subscriptions collection
    await _firestoreService.saveSubscription(updatedSub);

    final historyEntry = SubscriptionHistoryEntry(
      plan: plan.planKey,
      action: adminGranted ? 'admin_granted' : 'purchased',
      date: now,
      amountPaid: amountPaid ?? (adminGranted ? 0 : plan.priceRs),
      note: adminNote,
    );

    await _firestoreService.updateSubscriptionHistory(companyId, historyEntry);

    // 2. Update Company doc so Field Users inherit the plan automatically
    await _db
        .collection('companies')
        .doc(companyId)
        .set({
      'plan': plan.planKey,
      'planExpiry': expiry != null ? Timestamp.fromDate(expiry) : null,
      'aiEnabled': plan.aiUnlocked,
      'status': 'active', 
    }, SetOptions(merge: true));

    await loadSubscription(companyId);
  }

  Future<void> cancelSubscription(String companyId) async {
    _isLoading = true;
    error = null;
    notifyListeners();
    try {
      final now = DateTime.now();
      
      final cancelledSub = SubscriptionModel(
        companyId: companyId,
        plan: 'free',
        status: 'active',
        startedAt: now,
        expiresAt: null,
      );
      await _firestoreService.saveSubscription(cancelledSub);

      final historyEntry = SubscriptionHistoryEntry(
        plan: _subscription?.plan ?? 'unknown',
        action: 'cancelled',
        date: now,
        note: 'Subscription cancelled by user.',
      );
      await _firestoreService.updateSubscriptionHistory(companyId, historyEntry);

      await _db
          .collection('companies')
          .doc(companyId)
          .set({
        'plan': 'free',
        'planExpiry': null,
        'aiEnabled': false,
      }, SetOptions(merge: true));

      await loadSubscription(companyId);
      successMessage = 'Subscription cancelled. You are now on the Free plan.';
    } catch (e) {
      error = 'Failed to cancel subscription: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    error = null;
    successMessage = null;
    notifyListeners();
  }
}
