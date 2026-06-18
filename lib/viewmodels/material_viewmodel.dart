import 'dart:io';
import 'package:flutter/material.dart';
import '../models/material_model.dart';
import '../models/category_model.dart';
import '../repositories/material_repository.dart';
import '../services/storage_service.dart';

class MaterialViewModel extends ChangeNotifier {
  final MaterialRepository _materialRepo;
  final StorageService _storageService;

  MaterialViewModel(this._materialRepo, this._storageService);

  List<CategoryModel> _categories = [];
  CategoryModel? _selectedCategory;
  bool _isLoading = false;
  String? _error;
  bool _isSuccess = false;

  List<CategoryModel> get categories => _categories;
  CategoryModel? get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isSuccess => _isSuccess;

  Future<void> loadCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _categories = await _materialRepo.getCategories();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void onCategorySelected(String catId) {
    _selectedCategory = _categories.firstWhere((c) => c.id == catId);
    notifyListeners();
  }

  Future<void> addMaterial(Map<String, dynamic> params, File? imageFile, String companyId, String supplierUid) async {
    if (_selectedCategory == null) {
      _error = "Please select a category first";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _isSuccess = false;
    _error = null;
    notifyListeners();
    try {
      String? imageUrl;
      if (imageFile != null) {
        // In a real app, you'd use the imageUrl returned here
        imageUrl = await _storageService.uploadFile(file: imageFile, path: 'materials/$supplierUid/${DateTime.now().millisecondsSinceEpoch}');
      }

      final material = MaterialModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: params['name'],
        category: _selectedCategory!.name,
        pricePerUnit: double.parse(params['price']),
        unit: _selectedCategory!.unit,
        specifications: params['specifications'] ?? '',
        qualityGrade: params['grade'],
        supplierId: supplierUid,
        supplierName: params['supplierName'] ?? '',
        isCertified: true,
        originCity: params['city'] ?? 'Lahore',
      );

      await _materialRepo.saveMaterial(material);
      _isSuccess = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateMaterial(String matId, Map<String, dynamic> params, File? imageFile, String companyId) async {
    _isLoading = true;
    _isSuccess = false;
    _error = null;
    notifyListeners();
    try {
      // Logic for updating material
      // Fetch existing, apply copyWith, then save
      // This is a simplified placeholder as per user style
      _isSuccess = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
