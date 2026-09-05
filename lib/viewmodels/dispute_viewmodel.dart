import 'package:flutter/material.dart';
import '../models/dispute_model.dart';
import '../services/cloud_function_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../utils/app_exception.dart';

class DisputeViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final CloudFunctionService _cloudFunctions;
  final NotificationService? _notificationService;

  DisputeViewModel(
    this._firestoreService,
    this._cloudFunctions, [
    this._notificationService,
  ]);

  bool _isLoading = false;
  String? _error;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> raiseDispute({
    required String uid,
    required String orderId,
    required String companyId,
    required DisputeType type,
    required String description,
    String? photoUrl,
    String raisedByRole = 'field_user',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.createDisputeJob(
        uid: uid,
        orderId: orderId,
        companyId: companyId,
        type: type.name,
        description: description,
        photoUrl: photoUrl,
      );
      await _notifyAdminsDisputeRaised(
        orderId: orderId,
        companyId: companyId,
        raisedByRole: raisedByRole,
      );
    } on AppException catch (error) {
      _error = error.message;
      rethrow;
    } catch (error) {
      _error = error.toString();
      throw AppException(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _notifyAdminsDisputeRaised({
    required String orderId,
    required String companyId,
    required String raisedByRole,
  }) async {
    final notifications = _notificationService;
    if (notifications == null) return;
    try {
      final adminIds = await _firestoreService.getAdminUserIds();
      for (final adminUid in adminIds) {
        await notifications.notifyDisputeRaised(
          adminUid: adminUid,
          orderId: orderId,
          companyId: companyId,
          raisedByRole: raisedByRole,
        );
      }
    } catch (_) {
      // Dispute already persisted; admin alert is best-effort.
    }
  }

  Stream<List<DisputeModel>> watchCompanyDisputes(String companyId) {
    return _firestoreService.streamCompanyDisputes(companyId);
  }

  Stream<List<DisputeModel>> watchAllDisputes({String? status}) {
    return _firestoreService.streamAllDisputes(status: status);
  }

  Stream<List<DisputeModel>> watchMyDisputes(String uid) {
    return _firestoreService.streamRaisedByDisputes(uid);
  }

  Future<void> resolveDispute(
    String id,
    String status,
    String notes, {
    required String adminUid,
    String? raisedByUid,
    String? raisedByRole,
    String? orderId,
    String? companyId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      if (adminUid.trim().isEmpty) {
        throw AppException('You must be signed in as an administrator.');
      }
      await _firestoreService.createDisputeUpdateJob(
        uid: adminUid,
        disputeId: id,
        status: status,
        resolutionNotes: notes,
      );
      await _notifyRaisedByOutcome(
        status: status,
        notes: notes,
        raisedByUid: raisedByUid,
        raisedByRole: raisedByRole,
        orderId: orderId,
        companyId: companyId,
      );
    } on AppException catch (error) {
      _error = error.message;
      rethrow;
    } catch (error) {
      _error = error.toString();
      throw AppException(_error!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _notifyRaisedByOutcome({
    required String status,
    required String notes,
    String? raisedByUid,
    String? raisedByRole,
    String? orderId,
    String? companyId,
  }) async {
    final notifications = _notificationService;
    final uid = raisedByUid?.trim() ?? '';
    final closed =
        status == 'resolved' || status == 'rejected';
    if (notifications == null || uid.isEmpty || !closed) return;
    try {
      await notifications.notifyDisputeResolved(
        recipientUid: uid,
        recipientRole: (raisedByRole ?? '').trim().isEmpty
            ? 'field_user'
            : raisedByRole!.trim(),
        orderId: orderId ?? '',
        companyId: companyId ?? '',
        status: status,
        resolutionNotes: notes,
      );
    } catch (_) {
      // Dispute already updated; in-app alert is best-effort.
    }
  }
}
