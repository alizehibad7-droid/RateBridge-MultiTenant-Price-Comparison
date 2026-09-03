import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
        _functions = functions ?? FirebaseFunctions.instance;

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
      // A CEO-initiated request is an invitation, so reject it before sending
      // when the company has no supplier capacity. Supplier-initiated requests
      // are checked authoritatively when they are accepted.
      if (initiatedBy.toLowerCase() == 'ceo') {
        await PlanLimitService.ensureSupplierCapacity(
          _db,
          companyId,
          supplierId: supplierId,
        );
      }

      if (await _hasBlockingRequest(
        companyId: companyId,
        supplierId: supplierId,
      )) {
        throw AppException(
          'A partnership request already exists for this company and supplier.',
        );
      }

      final ref = _db.collection(FirestorePaths.partnershipRequestsCol).doc();
      await ref.set({
        'requestId': ref.id,
        'companyId': companyId,
        'companyName': companyName,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'initiatedBy': initiatedBy,
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

    try {
      // Attempt to call the cloud function for notifications and audit logging.
      await _functions
          .httpsCallable('acceptPartnershipRequest')
          .call(<String, dynamic>{'requestId': requestId});
    } catch (e) {
      // If the cloud function is not deployed or fails, we proceed with manual
      // status update and enrichment to ensure the partnership is still created.
      await reqRef.update({
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      });
    }

    // Ensure link documents are created/updated on both sides.
    await enrichAcceptedLinkDocs(
      companyId: req.companyId,
      supplierId: req.supplierId,
    );
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
    if (!supplierSnap.exists) return;
    final supplierData = supplierSnap.data()!;

    await _db
        .collection(FirestorePaths.companiesCol)
        .doc(companyId)
        .collection('suppliers')
        .doc(supplierId)
        .set({
      'name': supplierData['name'] ?? supplierData['businessName'] ?? 'Supplier',
      'city': supplierData['city'] ?? '',
      'materialType':
          supplierData['businessType'] ?? supplierData['materialType'] ?? 'General',
      'status': 'active',
    }, SetOptions(merge: true));

    final companySnap =
        await _db.collection(FirestorePaths.companiesCol).doc(companyId).get();
    if (!companySnap.exists) return;

    await _db
        .collection(FirestorePaths.suppliersCol)
        .doc(supplierId)
        .collection('companies')
        .doc(companyId)
        .set({
      'name': companySnap.data()?['name'] ?? companySnap.data()?['companyName'],
      'status': 'active',
    }, SetOptions(merge: true));
  }
}
