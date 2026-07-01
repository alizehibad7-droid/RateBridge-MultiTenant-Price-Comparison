import 'package:flutter/material.dart';
import '../../models/rating_model.dart';
import '../../repositories/order_repository.dart';

enum FieldRatingSubmitResult { success, alreadyRated, failure }

/// Post-delivery supplier rating submission for field users.
class FieldRatingViewModel extends ChangeNotifier {
  final OrderRepository _orderRepo;

  bool _isLoading = false;
  bool _isCheckingExisting = false;
  String? _errorMessage;

  FieldRatingViewModel(this._orderRepo);

  bool get isLoading => _isLoading;
  bool get isCheckingExisting => _isCheckingExisting;
  String? get errorMessage => _errorMessage;

  Future<bool> hasUserRatedOrder(String orderId, String userId) async {
    _isCheckingExisting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      return await _orderRepo.hasRatingForOrderByUser(orderId, userId);
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isCheckingExisting = false;
      notifyListeners();
    }
  }

  Future<FieldRatingSubmitResult> submitRating({
    required String orderId,
    required String companyId,
    required RatingModel rating,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final alreadyRated = await _orderRepo.hasRatingForOrderByUser(
        orderId,
        rating.userId,
      );
      if (alreadyRated) {
        return FieldRatingSubmitResult.alreadyRated;
      }

      await _orderRepo.submitRating(orderId, companyId, rating);
      try {
        await _orderRepo.updateSupplierAvgRating(rating.supplierUid);
      } catch (_) {
        // Rating is saved; supplier avg may sync on a later rating.
      }
      return FieldRatingSubmitResult.success;
    } catch (e) {
      _errorMessage = e.toString();
      return FieldRatingSubmitResult.failure;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
