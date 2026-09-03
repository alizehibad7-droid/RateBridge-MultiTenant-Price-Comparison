import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/material_model.dart';
import '../models/category_model.dart';
import '../repositories/material_repository.dart';
import '../services/cloudinary_service.dart';

typedef MaterialImageUploader = Future<String?> Function({
  required List<int> bytes,
  required String folder,
  String filename,
});

class MaterialViewModel extends ChangeNotifier {
  final MaterialRepository _materialRepo;
  final MaterialImageUploader _uploadImage;

  MaterialViewModel(
    this._materialRepo, {
    MaterialImageUploader? uploadImage,
  }) : _uploadImage = uploadImage ?? CloudinaryService.uploadImageBytes;

  List<CategoryModel> _categories = [];
  CategoryModel? _selectedCategory;
  bool _isLoading = false;
  String? _error;
  bool _isSuccess = false;

  bool _isLoadingCategories = false;

  List<CategoryModel> get categories => _categories;
  CategoryModel? get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  bool get isLoadingCategories => _isLoadingCategories;
  String? get error => _error;
  bool get isSuccess => _isSuccess;

  void resetSuccess() {
    _isSuccess = false;
    notifyListeners();
  }

  /// Clears add-material form state when opening the add screen.
  void resetAddMaterialForm() {
    _selectedCategory = null;
    _error = null;
    _isSuccess = false;
    notifyListeners();
  }

  Future<void> loadCategories() async {
    _isLoadingCategories = true;
    _error = null;
    notifyListeners();
    try {
      _categories = await _materialRepo.getCategories();
      if (_selectedCategory != null &&
          !_categories.any((c) => c.id == _selectedCategory!.id)) {
        _selectedCategory = null;
      }
    } catch (e) {
      _error = e.toString();
      _categories = [];
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  void onCategorySelected(String catId) {
    try {
      _selectedCategory = _categories.firstWhere((c) => c.id == catId);
    } catch (_) {
      _selectedCategory = null;
    }
    notifyListeners();
  }

  void selectCategoryByName(String categoryName) {
    try {
      _selectedCategory =
          _categories.firstWhere((c) => c.name == categoryName);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> addMaterial(
    Map<String, dynamic> params,
    XFile? imageFile,
    String companyId,
    String supplierUid,
  ) async {
    if (_selectedCategory == null) {
      _error = 'Please select a category first';
      notifyListeners();
      return;
    }

    if (imageFile == null) {
      _error = 'Material photo is required';
      notifyListeners();
      return;
    }

    if (companyId.trim().isEmpty) {
      _error = 'No company selected. Please select a company before adding materials.';
      notifyListeners();
      return;
    }

    if (supplierUid.trim().isEmpty) {
      _error = 'Supplier account not found. Please sign in again.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _isSuccess = false;
    _error = null;
    notifyListeners();
    try {
      String? imageUrl;
      final bytes = await imageFile.readAsBytes();
      imageUrl = await _uploadImage(
        bytes: bytes,
        folder: 'ratebridge/materials',
        filename: imageFile.name.isNotEmpty ? imageFile.name : 'material.jpg',
      );
      if (imageUrl == null) {
        _error = 'Image upload failed. Please try again.';
        return;
      }

      final minOrderRaw = params['minOrderQuantity']?.toString().trim();
      final minOrder = minOrderRaw != null && minOrderRaw.isNotEmpty
          ? double.tryParse(minOrderRaw)
          : null;

      final bulkDiscount = params['bulkDiscountAvailable'] == true;
      final bulkDetails = params['bulkDiscountDetails']?.toString().trim();

      final material = MaterialModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: params['name'] as String,
        category: _selectedCategory!.name,
        pricePerUnit: double.parse(params['price'].toString()),
        unit: _selectedCategory!.unit,
        specifications: params['specifications']?.toString() ?? '',
        qualityGrade: params['grade']?.toString() ?? '',
        supplierId: supplierUid,
        supplierName: params['supplierName']?.toString() ?? '',
        isCertified: true,
        originCity: params['city']?.toString() ?? 'Lahore',
        profileImageUrl: imageUrl,
        brand: params['brand']?.toString(),
        stockStatus: params['stockStatus']?.toString() ?? 'Available',
        minOrderQuantity: minOrder,
        deliveryTime: params['deliveryTime']?.toString(),
        description: params['description']?.toString(),
        bulkDiscountAvailable: bulkDiscount,
        bulkDiscountDetails:
            bulkDiscount && bulkDetails != null && bulkDetails.isNotEmpty
                ? bulkDetails
                : null,
        deliveryCoverageArea: params['deliveryCoverageArea']?.toString(),
        deliveryCharges: params['deliveryCharges']?.toString(),
        createdAt: DateTime.now(),
      );

      await _materialRepo.saveMaterialWithCompany(material, companyId);
      await _materialRepo.recordInitialMaterialPrice(
        materialId: material.id,
        price: material.pricePerUnit,
        supplierUid: supplierUid,
      );
      _isSuccess = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateMaterial(
    String matId,
    Map<String, dynamic> params,
    XFile? imageFile,
    String companyId,
    String supplierUid,
  ) async {
    _isLoading = true;
    _isSuccess = false;
    _error = null;
    notifyListeners();
    try {
      final existing = await _materialRepo.getMaterialById(matId);
      if (existing == null) {
        _error = 'Material not found';
        return;
      }

      final updates = <String, dynamic>{
        'name': params['name'],
        'pricePerUnit': double.parse(params['price'].toString()),
        'brand': params['brand'],
        'qualityGrade': params['grade'],
        'stockStatus': params['stockStatus'] ?? 'Available',
      };

      final minOrderRaw = params['minOrderQuantity']?.toString().trim();
      if (minOrderRaw != null && minOrderRaw.isNotEmpty) {
        updates['minOrderQuantity'] = double.parse(minOrderRaw);
      } else {
        updates['minOrderQuantity'] = FieldValue.delete();
      }

      final deliveryTime = params['deliveryTime']?.toString().trim();
      updates['deliveryTime'] = deliveryTime != null && deliveryTime.isNotEmpty
          ? deliveryTime
          : FieldValue.delete();

      if (params.containsKey('description')) {
        final description = params['description']?.toString().trim();
        updates['description'] =
            description != null && description.isNotEmpty
                ? description
                : FieldValue.delete();
      }

      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        final imageUrl = await _uploadImage(
          bytes: bytes,
          folder: 'ratebridge/materials',
          filename: imageFile.name.isNotEmpty ? imageFile.name : 'material.jpg',
        );
        if (imageUrl == null) {
          _error = 'Image upload failed. Please try again.';
          return;
        }
        updates['profileImageUrl'] = imageUrl;
      }

      final newPrice = updates['pricePerUnit'] as double;
      if (existing.pricePerUnit != newPrice) {
        await _materialRepo.archiveMaterialPriceChange(
          materialId: matId,
          previousPrice: existing.pricePerUnit,
          newPrice: newPrice,
          supplierUid: supplierUid,
        );
      }

      await _materialRepo.updateMaterialFields(matId, companyId, updates);
      _isSuccess = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
