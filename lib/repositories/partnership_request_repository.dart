import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../constants/firestore_paths.dart';
import '../models/partnership_request_model.dart';
import '../services/firestore_service.dart';
import '../services/plan_limit_service.dart';
import '../utils/app_exception.dart';
import '../utils/partnership_stream_utils.dart';

class PartnershipRequestRepository {
  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  PartnershipRequestRepository(
    FirestoreService _, {
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<bool> _hasBlockingRequest({
    required String companyId,
    required String supplierId,
  }) async {
    final snap = await _db
        .collection(FirestorePaths.partnershipRequestsCol)
        .where('companyId', isEqualTo: companyId)
        .where('supplierId', isEqualTo: supplierId)
        .get();

    return snap.docs.any((doc) {
      final status = (doc.data()['status'] as String?)?.toLowerCase() ?? '';
      return status == 'pending' || status == 'accepted';
    });
  }

  Future<String> createRequest({
    required String companyId,
    required String companyName,
    required String supplierId,
    required String supplierName,
    required String initiatedBy,
    String? message,
    String? supplierEmail,
    String? supplierCity,
    List<String> supplierCategories = const [],
    double supplierRating = 0,
  }) async {
    try {
      // Resolve canonical Firestore document IDs so CEO/supplier watches match.
      final companySnap =
          await _db.collection(FirestorePaths.companiesCol).doc(companyId).get();
      if (!companySnap.exists) {
        throw AppException('Company not found. Please refresh and try again.');
      }
      final canonicalCompanyId = companySnap.id;
      final resolvedCompanyName = (companySnap.data()?['name'] ??
              companySnap.data()?['companyName'] ??
              companyName)
          .toString();

      final supplierSnap =
          await _db.collection(FirestorePaths.suppliersCol).doc(supplierId).get();
      if (!supplierSnap.exists) {
        throw AppException('Supplier not found. Please refresh and try again.');
      }
      final canonicalSupplierId = supplierSnap.id;
      final resolvedSupplierName = (supplierSnap.data()?['name'] ??
              supplierSnap.data()?['businessName'] ??
              supplierName)
          .toString();

      final by = initiatedBy.toLowerCase() == 'company'
          ? 'ceo'
          : initiatedBy.toLowerCase();

      // A CEO-initiated request is an invitation, so reject it before sending
      // when the company has no supplier capacity. Supplier-initiated requests
      // are checked authoritatively when they are accepted.
      if (by == 'ceo') {
        await PlanLimitService.ensureSupplierCapacity(
          _db,
          canonicalCompanyId,
          supplierId: canonicalSupplierId,
        );
      }

      if (await _hasBlockingRequest(
        companyId: canonicalCompanyId,
        supplierId: canonicalSupplierId,
      )) {
        throw AppException(
          'A partnership request already exists for this company and supplier.',
        );
      }

      final ref = _db.collection(FirestorePaths.partnershipRequestsCol).doc();
      await ref.set({
        'requestId': ref.id,
        'companyId': canonicalCompanyId,
        'companyName': resolvedCompanyName,
        'supplierId': canonicalSupplierId,
        'supplierName': resolvedSupplierName,
        'initiatedBy': by == 'ceo' ? 'ceo' : 'supplier',
        'status': 'pending',
        'message': message,
        'rejectionReason': null,
        'createdAt': FieldValue.serverTimestamp(),
        'respondedAt': null,
        if (supplierEmail != null) 'supplierEmail': supplierEmail,
        if (supplierCity != null) 'supplierCity': supplierCity,
        if (supplierCategories.isNotEmpty)
          'supplierCategories': supplierCategories,
        'supplierRating': supplierRating,
      });
      return ref.id;
    } on AppException {
      rethrow;
    } on FirebaseException catch (e) {
      throw AppException(
        e.message ?? 'Failed to create partnership request.',
      );
    }
  }

  Stream<PartnershipRequestModel?> watchLatestForPair({
    required String companyId,
    required String supplierId,
  }) {
    return _db
        .collection(FirestorePaths.partnershipRequestsCol)
        .where('companyId', isEqualTo: companyId)
        .where('supplierId', isEqualTo: supplierId)
        .snapshots()
        .map((snap) => newestPartnershipRequest(snap.docs));
  }

  Stream<List<PartnershipRequestModel>> watchForCompany({
    required String companyId,
    required String initiatedBy,
  }) {
    return _db
        .collection(FirestorePaths.partnershipRequestsCol)
        .where('companyId', isEqualTo: companyId)
        .where('initiatedBy', isEqualTo: initiatedBy)
        .snapshots()
        .map((snap) => sortPartnershipRequestsNewest(snap.docs));
  }

  Stream<List<PartnershipRequestModel>> watchForSupplier({
    required String supplierId,
    required String initiatedBy,
  }) {
    return _db
        .collection(FirestorePaths.partnershipRequestsCol)
        .where('supplierId', isEqualTo: supplierId)
        .where('initiatedBy', isEqualTo: initiatedBy)
        .snapshots()
        .map((snap) => sortPartnershipRequestsNewest(snap.docs));
  }

  Stream<int> watchPendingCountForCompany(String companyId) {
    return _db
        .collection(FirestorePaths.partnershipRequestsCol)
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: 'pending')
        .where('initiatedBy', isEqualTo: 'supplier')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> acceptRequest(String requestId) async {
    final reqRef =
        _db.collection(FirestorePaths.partnershipRequestsCol).doc(requestId);
    final reqSnap = await reqRef.get();
    if (!reqSnap.exists) {
      throw AppException('Partnership request not found.');
    }
    final req = PartnershipRequestModel.fromMap(requestId, reqSnap.data()!);
    if (req.status != 'pending') {
      throw AppException('This request is no longer pending.');
    }
    if (req.companyId.isEmpty || req.supplierId.isEmpty) {
      throw AppException(
        'Partnership request is missing company or supplier.',
      );
    }

    // Capacity check before linking (subscription-aware).
    await PlanLimitService.ensureSupplierCapacity(
      _db,
      req.companyId,
      supplierId: req.supplierId,
    );

    // Client-first accept: Cloud Function has been unreliable (often never
    // invoked / not-found). Write links directly, then best-effort CF notify.
    await _acceptLocally(
      requestId: requestId,
      companyId: req.companyId,
      supplierId: req.supplierId,
    );

    try {
      await _functions
          .httpsCallable('acceptPartnershipRequest')
          .call(<String, dynamic>{'requestId': requestId})
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      // Already accepted locally — ignore callable failures.
      debugPrint('acceptPartnershipRequest CF skipped after local accept: $e');
    }
  }

  /// Marks the request accepted and creates both-side partnership link docs.
  Future<void> _acceptLocally({
    required String requestId,
    required String companyId,
    required String supplierId,
  }) async {
    final supplierSnap =
        await _db.collection(FirestorePaths.suppliersCol).doc(supplierId).get();
    if (!supplierSnap.exists) {
      throw AppException(
        'Supplier profile not found. Partnership could not be linked.',
      );
    }
    final supplierData = supplierSnap.data()!;
    final displayName =
        (supplierData['name'] ?? supplierData['businessName'] ?? 'Supplier')
            .toString();

    final companySnap =
        await _db.collection(FirestorePaths.companiesCol).doc(companyId).get();
    if (!companySnap.exists) {
      throw AppException(
        'Company profile not found. Partnership could not be linked.',
      );
    }
    final companyName =
        (companySnap.data()?['name'] ?? companySnap.data()?['companyName'] ?? '')
            .toString();

    final existingLink = await _db
        .collection(FirestorePaths.companiesCol)
        .doc(companyId)
        .collection('suppliers')
        .doc(supplierId)
        .get();
    final existingStatus =
        (existingLink.data()?['status'] as String?)?.trim().toLowerCase() ?? '';
    final alreadyLinked = existingLink.exists &&
        (existingStatus == 'active' || existingStatus == 'approved');

    final batch = _db.batch();
    batch.update(
      _db.collection(FirestorePaths.partnershipRequestsCol).doc(requestId),
      {
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      },
    );
    batch.set(
      _db
          .collection(FirestorePaths.companiesCol)
          .doc(companyId)
          .collection('suppliers')
          .doc(supplierId),
      {
        'id': supplierId,
        'supplierUid': supplierId,
        'name': displayName,
        'businessName':
            supplierData['businessName'] ?? supplierData['name'] ?? displayName,
        'supplierName':
            supplierData['businessName'] ?? supplierData['name'] ?? displayName,
        'city': supplierData['city'] ?? '',
        'materialType':
            supplierData['businessType'] ??
            supplierData['materialType'] ??
            'General',
        'email': supplierData['email'] ?? '',
        'status': 'active',
        'linkedAt': FieldValue.serverTimestamp(),
        'joinedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    batch.set(
      _db
          .collection(FirestorePaths.suppliersCol)
          .doc(supplierId)
          .collection('companies')
          .doc(companyId),
      {
        'id': companyId,
        'name': companyName,
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
        'onboardingComplete': false,
      },
      SetOptions(merge: true),
    );
    if (!alreadyLinked) {
      batch.set(
        _db.collection(FirestorePaths.suppliersCol).doc(supplierId),
        {'totalCompanies': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
    }

    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      debugPrint(
        'acceptLocally batch failed: code=${e.code} message=${e.message}',
      );
      throw AppException(
        e.message ?? 'Failed to accept partnership request.',
        e.code,
      );
    }
  }

  Future<void> withdrawRequest(String requestId) async {
    final reqRef =
        _db.collection(FirestorePaths.partnershipRequestsCol).doc(requestId);
    final reqSnap = await reqRef.get();
    if (!reqSnap.exists) {
      throw AppException('Partnership request not found.');
    }
    final status =
        (reqSnap.data()?['status'] as String?)?.toLowerCase() ?? '';
    if (status != 'pending') {
      throw AppException('Only pending requests can be withdrawn.');
    }
    await reqRef.delete();
  }

  Future<void> rejectRequest(String requestId, String reason) async {
    final reqRef =
        _db.collection(FirestorePaths.partnershipRequestsCol).doc(requestId);
    final reqSnap = await reqRef.get();
    if (!reqSnap.exists) {
      throw AppException('Partnership request not found.');
    }
    final status =
        (reqSnap.data()?['status'] as String?)?.toLowerCase() ?? '';
    if (status != 'pending') {
      throw AppException('This request is no longer pending.');
    }

    try {
      await reqRef.update({
        'status': 'rejected',
        'rejectionReason': reason.trim(),
        'respondedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AppException(
        e.message ?? 'Failed to reject partnership request.',
      );
    }
  }

  Future<void> removePartnership({
    required String companyId,
    required String supplierId,
  }) async {
    final batch = _db.batch();

    batch.delete(
      _db
          .collection(FirestorePaths.companiesCol)
          .doc(companyId)
          .collection('suppliers')
          .doc(supplierId),
    );
    batch.delete(
      _db
          .collection(FirestorePaths.suppliersCol)
          .doc(supplierId)
          .collection('companies')
          .doc(companyId),
    );

    final accepted = await _db
        .collection(FirestorePaths.partnershipRequestsCol)
        .where('companyId', isEqualTo: companyId)
        .where('supplierId', isEqualTo: supplierId)
        .where('status', isEqualTo: 'accepted')
        .limit(1)
        .get();

    if (accepted.docs.isNotEmpty) {
      batch.update(accepted.docs.first.reference, {
        'status': 'removed',
        'respondedAt': FieldValue.serverTimestamp(),
      });
    }

    final supplierRef =
        _db.collection(FirestorePaths.suppliersCol).doc(supplierId);
    final supplierSnap = await supplierRef.get();
    if (supplierSnap.exists) {
      batch.set(supplierRef, {
        'totalCompanies': FieldValue.increment(-1),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> enrichAcceptedLinkDocs({
    required String companyId,
    required String supplierId,
  }) async {
    final supplierSnap =
        await _db.collection(FirestorePaths.suppliersCol).doc(supplierId).get();
    if (!supplierSnap.exists) {
      throw AppException(
        'Supplier profile not found. Partnership could not be linked.',
      );
    }
    final supplierData = supplierSnap.data()!;
    final displayName =
        (supplierData['name'] ?? supplierData['businessName'] ?? 'Supplier')
            .toString();

    await _db
        .collection(FirestorePaths.companiesCol)
        .doc(companyId)
        .collection('suppliers')
        .doc(supplierId)
        .set({
      'id': supplierId,
      'supplierUid': supplierId,
      'name': displayName,
      'businessName':
          supplierData['businessName'] ?? supplierData['name'] ?? displayName,
      'city': supplierData['city'] ?? '',
      'materialType':
          supplierData['businessType'] ??
          supplierData['materialType'] ??
          'General',
      'email': supplierData['email'] ?? '',
      'status': 'active',
      'linkedAt': FieldValue.serverTimestamp(),
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final companySnap =
        await _db.collection(FirestorePaths.companiesCol).doc(companyId).get();
    if (!companySnap.exists) {
      throw AppException(
        'Company profile not found. Partnership could not be linked.',
      );
    }
    final companyName =
        (companySnap.data()?['name'] ?? companySnap.data()?['companyName'] ?? '')
            .toString();

    await _db
        .collection(FirestorePaths.suppliersCol)
        .doc(supplierId)
        .collection('companies')
        .doc(companyId)
        .set({
      'id': companyId,
      'name': companyName,
      'status': 'active',
      'joinedAt': FieldValue.serverTimestamp(),
      'onboardingComplete': false,
    }, SetOptions(merge: true));
  }
}
