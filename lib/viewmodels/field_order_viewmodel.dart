import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/material_model.dart';
import '../repositories/order_repository.dart';
import '../repositories/material_repository.dart';
import '../services/firestore_service.dart';

class FieldOrderViewModel extends ChangeNotifier {
  final OrderRepository _orderRepo;
  final MaterialRepository _materialRepo;
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoading = false;
  String? error;
  List<OrderModel> _orders = [];
  List<MaterialModel> _marketplaceMaterials = [];
  List<MaterialModel> _filteredMaterials = [];
  
  FieldOrderViewModel(this._orderRepo, this._materialRepo);

  bool get isLoading => _isLoading;
  List<OrderModel> get orders => _orders;
  List<MaterialModel> get marketplaceMaterials => _filteredMaterials;

  // --- Marketplace ---
  Future<void> loadMarketplace(String companyId) async {
    _isLoading = true;
    error = null;
    notifyListeners();
    try {
      // Try to get materials from approved suppliers for this company
      final companyMaterials = await _materialRepo.getCompanyMaterials(companyId).first;
      
      if (companyMaterials.isNotEmpty) {
        _marketplaceMaterials = companyMaterials;
      } else {
        // Fallback to general popular materials
        _marketplaceMaterials = await _materialRepo.getPopularMaterials(companyId: companyId);
      }
      _filteredMaterials = List.from(_marketplaceMaterials);
    } catch (e) {
      error = "Failed to load marketplace: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void filterMaterials(String query) {
    if (query.isEmpty) {
      _filteredMaterials = List.from(_marketplaceMaterials);
    } else {
      _filteredMaterials = _marketplaceMaterials
          .where((m) => m.name.toLowerCase().contains(query.toLowerCase()) || 
                       m.category.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    notifyListeners();
  }

  // --- Orders ---
  Future<bool> placeOrder({
    required String companyId,
    required String fieldUserUid,
    required String fieldUserName,
    required MaterialModel material,
    required double quantity,
    required String siteLocation,
    required DateTime requiredDate,
    String? note,
  }) async {
    _isLoading = true;
    error = null;
    notifyListeners();
    try {
      final order = OrderModel(
        orderId: DateTime.now().millisecondsSinceEpoch.toString(),
        companyId: companyId,
        fieldUserUid: fieldUserUid,
        supplierId: material.supplierId,
        materialId: material.id,
        materialName: material.name,
        supplierName: material.supplierName,
        fieldUserName: fieldUserName,
        quantity: quantity,
        unit: material.unit,
        unitPrice: material.pricePerUnit,
        totalAmount: quantity * material.pricePerUnit,
        deliveryAddress: siteLocation,
        siteLocation: siteLocation,
        status: 'pending_approval',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        requiredDate: requiredDate,
        notes: note,
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

  Future<bool> submitWeightReport({
    required String orderId,
    required String companyId,
    required double actualWeight,
    String? remarks,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _orderRepo.updateOrder(orderId, {
        'actualWeight': actualWeight,
        'weightReportRemarks': remarks,
        'status': 'delivered',
        'updatedAt': DateTime.now(),
      });
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void loadMyOrders(String companyId, String fieldUserUid) {
    _orderRepo.watchFieldUserOrders(fieldUserUid, companyId, 'All').listen((data) {
      _orders = data;
      notifyListeners();
    });
  }

  void clearError() {
    error = null;
    notifyListeners();
  }
}
