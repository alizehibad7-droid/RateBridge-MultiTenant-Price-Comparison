import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';

import '../models/subscription_model.dart';
import '../models/payment_proof_model.dart';
import '../services/cloud_function_service.dart';
import '../services/firestore_service.dart';
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
  ])  : _db = firestore ?? FirebaseFirestore.instance,
        _uploadImageBytes =
            uploadImageBytes ?? CloudinaryService.uploadImageBytes;

  bool _isLoading = false;
  String? error;
  String? successMessage;
  SubscriptionModel? _subscription;
  PaymentProofModel? _pendingPayment;

  bool get isLoading => _isLoading;
  SubscriptionModel? get currentSubscription => _subscription;
  List<SubscriptionHistoryEntry> get history => _subscription?.history ?? [];
  PaymentProofModel? get pendingPayment => _pendingPayment;

  bool get hasPendingPayment => _pendingPayment != null;
  bool get isWaitingVerification => _pendingPayment?.status == 'pending';

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
      await _loadPendingPayment(companyId);
    } catch (e) {
      error = 'Failed to load subscription: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadPendingPayment(String companyId) async {
    final snap = await _db
        .collection('payment_proofs')
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: 'pending')
        .where('type', isEqualTo: 'subscription')
        .limit(1)
        .get();
    
    if (snap.docs.isNotEmpty) {
      _pendingPayment = PaymentProofModel.fromMap(snap.docs.first.id, snap.docs.first.data());
    } else {
      _pendingPayment = null;
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

  Future<bool> submitPaymentProof({
    required String ceoId,
    required String companyId,
    required String ceoName,
    required PlanDefinition plan,
    required String method,
    required double amount,
    required XFile screenshotFile,
  }) async {
    if (companyId.isEmpty) {
      error = "Invalid Company ID. Please log in again.";
      notifyListeners();
      return false;
    }

    _isLoading = true;
    error = null;
    successMessage = null;
    notifyListeners();

    try {
      // 1. Read bytes for upload
      final bytes = await screenshotFile.readAsBytes();
      if (bytes.isEmpty) throw Exception("Selected file is empty.");

      // 2. Upload to Cloudinary instead of Firebase Storage to bypass CORS/Storage errors
      final url = await _uploadImageBytes(
        bytes: bytes,
        folder: 'payment_proofs/$companyId',
        filename: '${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      
      if (url == null) throw Exception("Failed to upload screenshot to Cloudinary.");

      // 3. Create Payment Proof record in Firestore
      final proof = PaymentProofModel(
        id: '',
        payerId: ceoId,
        companyId: companyId,
        payerName: ceoName,
        payerRole: 'CEO',
        amount: amount,
        method: method,
        screenshotUrl: url,
        status: 'pending',
        type: 'subscription',
        planId: plan.planKey,
        planName: plan.name,
        createdAt: DateTime.now(),
      );

      await _db.collection('payment_proofs').add(proof.toMap());
      
      _pendingPayment = proof;
      successMessage = 'Payment proof submitted. Plan will be active after Admin verification.';
      return true;
    } catch (e) {
      debugPrint("Upload Error: $e");
      error = 'Failed to submit payment proof: ${e.toString()}';
      return false;
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
