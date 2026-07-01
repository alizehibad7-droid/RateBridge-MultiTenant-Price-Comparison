import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/payment_details_config.dart';
import '../models/subscription_model.dart';
import '../models/subscription_payment_model.dart';
import '../repositories/subscription_payment_repository.dart';
import '../services/cloudinary_service.dart';
import '../services/firestore_service.dart';

class SubscriptionViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final SubscriptionPaymentRepository _paymentRepo;

  SubscriptionViewModel(this._firestoreService, this._paymentRepo);

  bool _isLoading = false;
  String? error;
  String? successMessage;
  SubscriptionModel? _subscription;
  PaymentDetailsConfig _paymentDetails = const PaymentDetailsConfig();
  SubscriptionPaymentModel? _latestPayment;

  bool get isLoading => _isLoading;
  SubscriptionModel? get currentSubscription => _subscription;
  List<SubscriptionHistoryEntry> get history => _subscription?.history ?? [];
  PaymentDetailsConfig get paymentDetails => _paymentDetails;
  SubscriptionPaymentModel? get latestPayment => _latestPayment;

  bool get hasPendingPayment => _latestPayment?.isPending ?? false;
  bool get hasRejectedPayment => _latestPayment?.isRejected ?? false;

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
      await loadPaymentDetails();
    } catch (e) {
      error = 'Failed to load subscription: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPaymentDetails() async {
    try {
      _paymentDetails = await _paymentRepo.getPaymentDetails();
    } catch (_) {
      _paymentDetails = const PaymentDetailsConfig();
    }
    notifyListeners();
  }

  void watchLatestPayment(String companyId) {
    if (companyId.isEmpty) return;
    _paymentRepo.watchLatestCompanyPayment(companyId).listen(
      (payment) {
        _latestPayment = payment;
        notifyListeners();
      },
      onError: (_) {},
    );
  }

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
      return sub;
    });
  }

  Future<void> submitManualPayment({
    required String companyId,
    required String companyName,
    required String ceoUid,
    required PlanDefinition plan,
    required File proofFile,
  }) async {
    if (plan.id == PlanId.free) return;

    _isLoading = true;
    error = null;
    successMessage = null;
    notifyListeners();

    try {
      final proofUrl = await CloudinaryService.uploadImage(
        filePath: proofFile.path,
        folder: 'ratebridge/subscription_payments',
      );
      if (proofUrl == null) {
        error = 'Image upload failed. Please try again.';
        return;
      }

      final payment = SubscriptionPaymentModel(
        id: '',
        companyId: companyId,
        companyName: companyName,
        submittedByUid: ceoUid,
        plan: plan.planKey,
        amount: plan.priceRs,
        paymentProofUrl: proofUrl,
        status: 'pending',
        submittedAt: DateTime.now(),
      );

      await _paymentRepo.submitPayment(payment);
      await _paymentRepo.notifyAdminsNewPayment(companyName);
      _latestPayment = payment;

      successMessage =
          'Payment submitted for review. We will notify you once approved.';
    } catch (e) {
      error = 'Could not submit payment: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
      await _activateSubscription(
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

  Future<void> savePaymentDetails(PaymentDetailsConfig config) async {
    _isLoading = true;
    error = null;
    successMessage = null;
    notifyListeners();
    try {
      await _paymentRepo.savePaymentDetails(config);
      _paymentDetails = config;
      successMessage = 'Payment details saved.';
    } catch (e) {
      error = 'Failed to save payment details: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _activateSubscription({
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

    await _firestoreService.saveSubscription(updatedSub);

    final historyEntry = SubscriptionHistoryEntry(
      plan: plan.planKey,
      action: adminGranted ? 'admin_granted' : 'purchased',
      date: now,
      amountPaid: amountPaid ?? (adminGranted ? 0 : plan.priceRs),
      note: adminNote,
    );

    await _firestoreService.updateSubscriptionHistory(companyId, historyEntry);

    await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .set({'plan': plan.planKey}, SetOptions(merge: true));

    await loadSubscription(companyId);
  }

  void clearMessages() {
    error = null;
    successMessage = null;
    notifyListeners();
  }
}
