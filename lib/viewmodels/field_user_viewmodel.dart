import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/order_model.dart';
import '../models/material_model.dart';
import '../models/price_trend_model.dart';
import '../repositories/material_repository.dart';
import '../repositories/order_repository.dart';
import '../services/gemini_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../services/firestore_service.dart';

class FieldUserViewModel extends ChangeNotifier {
  final MaterialRepository _materialRepo;
  final OrderRepository _orderRepo;
  final GeminiService _geminiService;
  final FirestoreService _firestoreService = FirestoreService();

  AuthViewModel? _authViewModel;
  UserModel? _user;
  String? _companyName;
  List<OrderModel> _myOrders = [];
  bool _isLoading = false;
  String? error;

  // Price Trend & Comparison State
  List<PriceTrendPoint> _priceTrend = [];
  String? _trendInsight;
  String _trendDirection = 'stable';
  List<dynamic> _compareResults = [];

  FieldUserViewModel(this._materialRepo, this._orderRepo, this._geminiService);

  // --- Getters ---
  bool get isLoading => _isLoading;
  UserModel? get user => _user;
  List<OrderModel> get myOrders => _myOrders;
  List<OrderModel> get recentOrders => _myOrders.take(5).toList();
  List<OrderModel> get siteOrders => _myOrders;

  String get fullName => _user?.name ?? '';
  String get phone => _user?.phone ?? '';
  String get email => _user?.email ?? '';
  String get companyName => _companyName ?? 'Loading...'; 
  DateTime? get joinedAt => _user?.createdAt;

  List<PriceTrendPoint> get priceTrend => _priceTrend;
  String? get trendInsight => _trendInsight;
  String get trendDirection => _trendDirection;
  List<dynamic> get compareResults => _compareResults;

  void updateAuth(AuthViewModel auth) {
    _authViewModel = auth;
    _user = auth.user;
    if (_user != null) {
      _listenToOrders();
      _loadCompanyName();
    }
    notifyListeners();
  }

  Future<void> _loadCompanyName() async {
    if (_user == null) return;
    try {
      final company = await _firestoreService.getCompany(_user!.companyId);
      _companyName = company?.name;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading company name: $e');
    }
  }

  Future<void> loadUserData(String uid) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _firestoreService.getUser(uid);
      if (_user != null) {
        await _loadCompanyName();
      }
    } catch (e) {
      error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _listenToOrders() {
    if (_user == null) return;
    _orderRepo.watchFieldUserOrders(_user!.uid, _user!.companyId, 'All').listen((orders) {
      _myOrders = orders;
      notifyListeners();
    });
  }

  Future<void> refreshHome() async {
    if (_user != null) {
      await loadUserData(_user!.uid);
    }
    notifyListeners();
  }

  Future<void> loadProfile() async {
    if (_user != null) {
      await loadUserData(_user!.uid);
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    if (_user == null) return false;
    _isLoading = true;
    error = null;
    notifyListeners();
    try {
      final updatedUser = _user!.copyWith(
        name: data['fullName'] ?? _user!.name,
        phone: data['phone'] ?? _user!.phone,
      );
      
      await _firestoreService.saveUser(updatedUser);
      _user = updatedUser;
      
      // Also update AuthViewModel if possible to keep in sync
      if (_authViewModel != null) {
        // This assumes AuthViewModel has a way to update its local user state
        // or it's listening to Firestore. Most common is just a local update.
      }
      
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<List<MaterialModel>> getCategoryMaterials(String category, {String? companyId, String? sort}) {
    return _materialRepo.streamCategoryMaterials(category, companyId: companyId ?? _user?.companyId, sort: sort);
  }

  // --- Price Trends & Comparison ---

  Future<void> loadPriceTrend(String companyId, String materialName) async {
    _isLoading = true;
    _priceTrend = [];
    _trendInsight = null;
    notifyListeners();

    try {
      // Mocking data for now, ideally fetched from repo/gemini
      _priceTrend = [
        PriceTrendPoint(date: DateTime.now().subtract(const Duration(days: 30)), price: 450),
        PriceTrendPoint(date: DateTime.now().subtract(const Duration(days: 15)), price: 470),
        PriceTrendPoint(date: DateTime.now().subtract(const Duration(days: 7)), price: 465),
        PriceTrendPoint(date: DateTime.now(), price: 480),
        PriceTrendPoint(date: DateTime.now().add(const Duration(days: 7)), price: 490, isForecast: true),
      ];
      _trendDirection = 'up';
      _trendInsight = "AI predicts a 5% price increase in the next week due to seasonal demand.";
    } catch (e) {
      error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCompareRates(String companyId, String materialName) async {
    _isLoading = true;
    _compareResults = [];
    notifyListeners();

    try {
      _compareResults = []; 
    } catch (e) {
      error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> placeOrder({
    required String materialId,
    required String materialName,
    required String supplierId,
    required String supplierName,
    required String unit,
    required double unitPrice,
    required double quantity,
    required String siteLocation,
    required DateTime requiredDate,
    String? notes,
  }) async {
    if (_user == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      final order = OrderModel(
        orderId: DateTime.now().millisecondsSinceEpoch.toString(),
        companyId: _user!.companyId,
        fieldUserUid: _user!.uid,
        supplierId: supplierId,
        materialId: materialId,
        materialName: materialName,
        supplierName: supplierName,
        fieldUserName: _user!.name,
        quantity: quantity,
        unit: unit,
        unitPrice: unitPrice,
        totalAmount: quantity * unitPrice,
        deliveryAddress: siteLocation,
        siteLocation: siteLocation,
        status: 'pending_approval',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        requiredDate: requiredDate,
        notes: notes,
      );

      await _orderRepo.submitOrder(order);
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }
}
