// MVVM: ViewModel — business logic only
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/rating_model.dart';
import '../repositories/order_repository.dart';
import '../services/cloud_function_service.dart';
import 'auth_viewmodel.dart';

class OrderViewModel extends ChangeNotifier {
  final OrderRepository _orderRepo;
  final CloudFunctionService _cloudFunctions;

  String? _uid;
  String? _companyId;
  String? _role;

  List<OrderModel> _orders = [];
  bool _isLoading = false;
  bool _isOrderPlaced = false;
  bool _isRatingSubmitted = false;
  String? _error;
  double _calculatedTotal = 0.0;
  bool? _hasExistingRating;
  StreamSubscription? _ordersSubscription;

  OrderViewModel(this._orderRepo, this._cloudFunctions);

  void updateAuth(AuthViewModel auth) {
    _uid = auth.user?.uid;
    _companyId = auth.user?.companyId;
    _role = auth.user?.role;
    notifyListeners();
  }

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  bool get isOrderPlaced => _isOrderPlaced;
  bool get isRatingSubmitted => _isRatingSubmitted;
  String? get error => _error;
  double get calculatedTotal => _calculatedTotal;
  bool? get hasExistingRating => _hasExistingRating;

  void updateQuantity(int qty, double unitPrice) {
    _calculatedTotal = qty * unitPrice;
    notifyListeners();
  }

  Future<void> placeOrder(OrderModel order) async {
    _isLoading = true;
    _error = null;
    _isOrderPlaced = false;
    notifyListeners();
    try {
      await _orderRepo.submitOrder(order);
      // Notifications for CEO would happen here usually
      _isOrderPlaced = true;
    } catch(e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// CEO Approves the field user's order request
  Future<void> ceoApproveOrder(String orderId, String companyId, String supplierUid) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _orderRepo.updateStatus(orderId, companyId, 'pending');
      
      // Notify supplier that a new approved order is available
      await _cloudFunctions.callFunction('sendOrderNotification', {
        'toUid': supplierUid,
        'orderId': orderId,
        'type': 'newOrder',
        'title': 'New Approved Order',
        'body': 'A new order has been approved and is ready for fulfillment.',
      });
    } catch(e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> confirmDelivery(String orderId, String companyId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _orderRepo.updateStatus(orderId, companyId, 'confirmed', confirmedAt: DateTime.now());
    } catch(e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> acceptOrder(String orderId, String companyId) async {
    await _updateOrderStatus(orderId, companyId, 'accepted');
  }

  Future<void> rejectOrder(String orderId, String companyId, String reason) async {
    await _updateOrderStatus(orderId, companyId, 'rejected', reason: reason);
  }

  Future<void> markDelivered(String orderId, String companyId) async {
    await _updateOrderStatus(orderId, companyId, 'delivered', deliveredAt: DateTime.now());
  }

  Future<void> cancelOrder(String orderId, String companyId) async {
    await _updateOrderStatus(orderId, companyId, 'cancelled');
  }

  Future<void> _updateOrderStatus(
    String orderId,
    String companyId,
    String status, {
    String? reason,
    DateTime? deliveredAt,
    DateTime? confirmedAt,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _orderRepo.updateStatus(orderId, companyId, status, 
        reason: reason, deliveredAt: deliveredAt, confirmedAt: confirmedAt);
    } catch(e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void loadCompanyOrders(String companyId, {String? statusFilter}) {
    _ordersSubscription?.cancel();
    _isLoading = true;
    notifyListeners();
    _ordersSubscription = _orderRepo
      .watchCompanyOrders(companyId, statusFilter ?? 'All')
      .listen((orders) {
        _orders = orders;
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      });
  }

  // ... rest of the load methods remain same
  void loadSupplierOrders(String supplierUid, String companyId, {String? statusFilter}) {
    _ordersSubscription?.cancel();
    _isLoading = true;
    notifyListeners();
    _ordersSubscription = _orderRepo
      .watchSupplierOrders(supplierUid, companyId, statusFilter ?? 'All')
      .listen((orders) {
        _orders = orders;
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      });
  }

  void loadFieldUserOrders(String fieldUserUid, String companyId, {String? statusFilter}) {
    _ordersSubscription?.cancel();
    _isLoading = true;
    notifyListeners();
    _ordersSubscription = _orderRepo
      .watchFieldUserOrders(fieldUserUid, companyId, statusFilter ?? 'All')
      .listen((orders) {
        _orders = orders;
        _isLoading = false;
        notifyListeners();
      }, onError: (e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      });
  }

  Future<void> checkExistingRating(String orderId, String companyId) async {
    _hasExistingRating = await _orderRepo.hasRatingForOrder(orderId, companyId);
    notifyListeners();
  }

  Future<void> submitRating(
    String orderId,
    String companyId,
    RatingModel rating,
  ) async {
    _isLoading = true;
    _isRatingSubmitted = false;
    _error = null;
    notifyListeners();
    try {
      await _orderRepo.submitRating(orderId, companyId, rating);
      await _orderRepo.updateSupplierAvgRating(rating.supplierUid, rating);
      _isRatingSubmitted = true;
    } catch(e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }
}
