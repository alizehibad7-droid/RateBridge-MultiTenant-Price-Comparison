import 'package:flutter/material.dart';
import '../models/dispute_model.dart';
import '../services/cloud_function_service.dart';
import '../services/firestore_service.dart';
import '../utils/app_exception.dart';

class DisputeViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final CloudFunctionService _cloudFunctions;

  DisputeViewModel(this._firestoreService, this._cloudFunctions);

  bool _isLoading = false;
  String? _error;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> raiseDispute({
    required String orderId,
    required String companyId,
    required DisputeType type,
    required String description,
    String? photoUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _cloudFunctions.callFunction('raiseDispute', {
        'orderId': orderId,
        'companyId': companyId,
        'type': type.name,
        'description': description,
        'photoUrl': photoUrl,
      });
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

  Stream<List<DisputeModel>> watchCompanyDisputes(String companyId) {
    return _firestoreService.streamCompanyDisputes(companyId);
  }

  Stream<List<DisputeModel>> watchAllDisputes({String? status}) {
    return _firestoreService.streamAllDisputes(status: status);
  }

  Future<void> resolveDispute(String id, String status, String notes) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _cloudFunctions.callFunction('updateDispute', {
        'disputeId': id,
        'status': status,
        'resolutionNotes': notes,
      });
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
}
