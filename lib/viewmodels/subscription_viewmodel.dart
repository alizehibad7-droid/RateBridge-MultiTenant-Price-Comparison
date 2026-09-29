import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../models/subscription_model.dart';
import '../services/cloud_function_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/cloudinary_service.dart';

class SubscriptionViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final CloudFunctionService _cloudFunctionService;
  final StorageService? _storageService;
  final FirebaseFirestore _db;
  final Future<String?> Function({
    required List<int> bytes,
    required String folder,
    String filename,
  }) _uploadImageBytes;
  final NotificationService? _notificationService;

  SubscriptionViewModel(
    this._firestoreService,
    this._cloudFunctionService, [
    this._storageService,
    FirebaseFirestore? firestore,
    Future<String?> Function({
      required List<int> bytes,
      required String folder,
      String filename,
    })? uploadImageBytes,
    NotificationService? notificationService,
  ])  : _db = firestore ?? FirebaseFirestore.instance,
        _uploadImageBytes =
            uploadImageBytes ?? CloudinaryService.uploadImageBytes,
        _notificationService = notificationService;

  bool _isLoading = false;
  String? error;
  String? successMessage;
  String? busyMessage;
  SubscriptionModel? _subscription;

  bool get isLoading => _isLoading;
  SubscriptionModel? get currentSubscription => _subscription;
  List<SubscriptionHistoryEntry> get history {
    final list =
        List<SubscriptionHistoryEntry>.from(_subscription?.history ?? const []);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  bool get isBusy => busyMessage != null && busyMessage!.isNotEmpty;

  void setBusyMessage(String? message) {
    busyMessage = message;
    notifyListeners();
  }

  /// Instant UI update so the plan does not flash back to Free after payment.
  void applyLocalPlan({
    required String companyId,
    required PlanDefinition plan,
    int? amountPaid,
  }) {
    final now = DateTime.now();
    final expiry = plan.durationDays > 0
        ? now.add(Duration(days: plan.durationDays))
        : null;
    final previous = _subscription?.history ?? const <SubscriptionHistoryEntry>[];
    final entry = SubscriptionHistoryEntry(
      plan: plan.planKey,
      action: 'purchased',
      date: now,
      amountPaid: amountPaid ?? plan.priceRs,
    );
    _subscription = SubscriptionModel(
      companyId: companyId,
      plan: plan.planKey,
      status: 'active',
      startedAt: now,
      expiresAt: expiry,
      adminGranted: false,
      history: [entry, ...previous],
    );
    successMessage = '${plan.name} plan activated successfully.';
    error = null;
    _isLoading = false;
    busyMessage = null;
    notifyListeners();
  }

  Future<void> loadSubscription(
    String companyId, {
    bool fromServer = false,
  }) async {
    if (companyId.isEmpty) return;
    final keepPlan = _subscription;
    _isLoading = keepPlan == null;
    error = null;
    notifyListeners();
    try {
      final loaded = await _firestoreService.getSubscription(
        companyId,
        fromServer: fromServer,
      );
      if (loaded != null) {
        _subscription = loaded;
      } else if (keepPlan != null &&
          keepPlan.companyId == companyId &&
          keepPlan.plan != 'free') {
        // Keep the plan we just activated — avoid Free flash from a stale miss.
        _subscription = keepPlan;
      } else {
        _subscription = SubscriptionModel(
          companyId: companyId,
          plan: 'free',
          status: 'active',
        );
      }
    } catch (e) {
      error = 'Failed to load subscription: $e';
      if (keepPlan != null && keepPlan.companyId == companyId) {
        _subscription = keepPlan;
      }
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
    _isLoading = true;
    error = null;
    successMessage = null;
    notifyListeners();
    try {
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
        history: _subscription?.history ?? const [],
      );

      await _firestoreService.saveSubscription(updatedSub);

      final historyEntry = SubscriptionHistoryEntry(
        plan: plan.planKey,
        action: adminGranted ? 'admin_granted' : 'purchased',
        date: now,
        amountPaid: amountPaid ?? (adminGranted ? 0 : plan.priceRs),
        note: adminNote,
      );

      await _firestoreService.updateSubscriptionHistory(companyId, historyEntry);

      try {
        await _db.collection('companies').doc(companyId).set({
          'plan': plan.planKey,
          'planExpiry': expiry != null ? Timestamp.fromDate(expiry) : null,
          'aiEnabled': plan.aiUnlocked,
          'status': 'active',
        }, SetOptions(merge: true));
      } catch (e) {
        // Subscription doc is the source of truth for Plan & Billing UI.
        debugPrint('Company plan sync skipped: $e');
      }

      await loadSubscription(companyId, fromServer: true);
      successMessage =
          '${plan.name} plan activated successfully.';
    } catch (e) {
      error = 'Failed to activate plan: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
