// MVVM: Repository — Firestore access only
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/join_request_model.dart';
import '../services/firestore_service.dart';
import '../constants/firestore_paths.dart';
import '../constants/app_constants.dart';
import '../utils/app_exception.dart';

class JoinRequestRepository {
  final FirebaseFirestore _db;

  JoinRequestRepository(FirestoreService _, {FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  Future<String> createJoinRequest(
    String supplierUid,
    String companyId,
    String supplierName,
    String supplierCity,
    List<String> categories,
    double rating,
    String? message, {
    String initiatedBy = 'supplier',
  }) async {
    try {
      final docRef = _db.collection(FirestorePaths.joinRequestsCol).doc();
      await docRef.set({
        'supplierUid': supplierUid,
        'supplierName': supplierName,
        'supplierCity': supplierCity,
        'supplierCategories': categories,
        'supplierRating': rating,
        'companyId': companyId,
        'message': message,
        'status': 'pending',
        'rejectionReason': null,
        'initiatedBy': initiatedBy,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } on FirebaseException catch(e) {
      throw AppException('Failed to create join request: ${e.message}');
    }
  }

  Stream<List<JoinRequestModel>> watchPendingRequests(String companyId) {
    try {
      return _db
          .collection(FirestorePaths.joinRequestsCol)
          .where('companyId', isEqualTo: companyId)
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(AppConstants.paginationLimit)
          .snapshots()
          .map((s) => s.docs.map((d) =>
            JoinRequestModel.fromMap(d.id, d.data())).toList());
    } on FirebaseException catch (e) {
      throw AppException('Failed to watch pending requests: ${e.message}');
    }
  }

  Future<void> updateRequestStatus(
    String reqId,
    String status, {
    String? reason,
  }) async {
    try {
      final Map<String, dynamic> updates = {'status': status};
      if (reason != null) updates['rejectionReason'] = reason;
      await _db
          .collection(FirestorePaths.joinRequestsCol)
          .doc(reqId)
          .update(updates);
    } on FirebaseException catch(e) {
      throw AppException('Failed to update request: ${e.message}');
    }
  }
}
