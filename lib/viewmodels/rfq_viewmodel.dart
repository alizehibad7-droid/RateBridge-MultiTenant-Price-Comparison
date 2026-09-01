import 'package:flutter/material.dart';
import '../models/rfq_model.dart';
import '../models/rfq_bid_model.dart';
import '../services/cloud_function_service.dart';
import '../services/firestore_service.dart';
import '../utils/app_exception.dart';

class RfqViewModel extends ChangeNotifier {
  final FirestoreService _firestoreService;
  final CloudFunctionService _cloudFunctions;

  bool _isLoading = false;
  String? _error;

  RfqViewModel(this._firestoreService, this._cloudFunctions);

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> createRfq({
    required String uid,
    required String companyId,
    required String companyName,
    required String category,
    required String materialDescription,
    required double quantity,
    required String unit,
    required String city,
    required DateTime requiredByDate,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firestoreService.createRfqJob(
        uid: uid,
        companyId: companyId,
        companyName: companyName,
        category: category,
        materialDescription: materialDescription,
        quantity: quantity,
        unit: unit,
        city: city,
        requiredByDate: requiredByDate,
      );
    } catch (e) {
      _error = e is AppException ? e.message : e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<List<RfqModel>> watchCompanyRfqs(String companyId) {
    return _firestoreService.streamCompanyRfqs(companyId);
  }

  Stream<RfqModel?> watchRfq(String rfqId) {
    return _firestoreService.streamRfq(rfqId);
  }

  Stream<List<RfqBidModel>> watchRfqBids(String rfqId) {
    return _firestoreService.streamRfqBids(rfqId);
  }

  Future<void> awardRfq({
    required RfqModel rfq,
    required RfqBidModel bid,
    required String ceoUid,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _cloudFunctions.callFunction('awardRfq', {
        'rfqId': rfq.id,
        'bidId': bid.id,
        'ceoUid': ceoUid,
      });
    } catch (e) {
      _error = e is AppException ? e.message : e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
