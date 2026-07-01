import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/material_listing.dart';
import '../models/material_model.dart';
import '../models/category_model.dart';
import '../models/price_history_model.dart';
import '../models/supplier_model.dart';
import '../services/firestore_service.dart';
import '../constants/app_constants.dart';

class MaterialRepository {
  final FirestoreService _firestoreService;

  MaterialRepository(this._firestoreService);

  Stream<List<MaterialModel>> getMaterials() {
    return _firestoreService.streamMaterials();
  }

  /// Get materials only from suppliers linked to the company
  Stream<List<MaterialModel>> getCompanyMaterials(String companyId) {
    return _firestoreService.streamCompanyMaterials(companyId);
  }

  Future<List<MaterialModel>> getPopularMaterials({String? companyId}) async {
    return _firestoreService.getPopularMaterials(companyId: companyId);
  }

  Future<List<MaterialModel>> getMaterialsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    return await _firestoreService.getMaterialsByIds(ids);
  }

  Future<bool> isSupplierLinkedToCompany(
    String companyId,
    String supplierId,
  ) async {
    final linked =
        await _firestoreService.getCompanyLinkedSupplierIds(companyId);
    return linked.contains(supplierId);
  }

  Future<MaterialModel?> getMaterialById(String id) async {
    return _firestoreService.getMaterialById(id);
  }

  Future<List<MaterialModel>> searchMaterials(String query) async {
    return await _firestoreService.searchMaterials(query);
  }

  Stream<List<MaterialModel>> streamCategoryMaterials(
    String category, {
    String? companyId,
    Map<String, dynamic>? filters,
    String? sort,
  }) {
    return _firestoreService.streamCategoryMaterials(
      category,
      companyId: companyId,
      filters: filters,
      sort: sort,
    );
  }

  Future<List<MaterialModel>> getApprovedSuppliersForMaterial(
    String materialName,
  ) async {
    return await _firestoreService.getApprovedSuppliersForMaterial(materialName);
  }

  /// Materials from company-linked suppliers matching [name] (case-insensitive).
  Future<List<MaterialModel>> getMaterialsByNameForCompany(
    String companyId,
    String name,
  ) async {
    return _firestoreService.getMaterialsByNameForCompany(companyId, name);
  }

  /// Enriched compare rows for the field-user comparison screen.
  Future<List<MaterialListing>> getCompareListingsForMaterial(
    String companyId,
    String materialName,
  ) async {
    final trimmedName = materialName.trim();
    if (trimmedName.isEmpty) return [];

    final materials =
        await getMaterialsByNameForCompany(companyId, trimmedName);
    if (materials.isEmpty) return [];

    final supplierCache = <String, SupplierModel?>{};

    Future<SupplierModel?> supplierFor(String supplierId) async {
      if (supplierCache.containsKey(supplierId)) {
        return supplierCache[supplierId];
      }
      final supplier = await _firestoreService.getSupplierById(supplierId);
      supplierCache[supplierId] = supplier;
      return supplier;
    }

    final listings = await Future.wait(
      materials.map((material) async {
        final ratingStats =
            await _firestoreService.getSupplierRatingStats(material.supplierId);
        final priceUpdatedAt =
            await _firestoreService.getLatestMaterialPriceTimestamp(material.id);
        final supplier = await supplierFor(material.supplierId);
        final city = supplier?.city.isNotEmpty == true
            ? supplier!.city
            : material.originCity;

        return MaterialListing(
          id: material.id,
          materialName: material.name,
          supplierName: supplier?.name.isNotEmpty == true
              ? supplier!.name
              : material.supplierName,
          supplierId: material.supplierId,
          pricePerUnit: material.pricePerUnit,
          unit: material.unit,
          supplierRating: ratingStats.average,
          reviewCount: ratingStats.count,
          stock: 1,
          category: material.category,
          city: city,
          phone: supplier?.contact,
          priceUpdatedAt: priceUpdatedAt ?? material.createdAt,
          brand: material.brand,
          qualityGrade: material.qualityGrade,
          description: material.description,
          minOrderQuantity: material.minOrderQuantity,
          deliveryTime: material.deliveryTime,
          deliveryCoverageArea: material.deliveryCoverageArea,
          deliveryCharges: material.deliveryCharges,
          bulkDiscountAvailable: material.bulkDiscountAvailable,
          bulkDiscountDetails: material.bulkDiscountDetails,
        );
      }),
    );

    listings.sort((a, b) => a.pricePerUnit.compareTo(b.pricePerUnit));
    return listings;
  }

  /// Backward-compatible alias used by older compare flows.
  Future<List<MaterialListing>> getCompareRatesForMaterial(
    String companyId,
    String materialName,
  ) =>
      getCompareListingsForMaterial(companyId, materialName);

  Future<void> saveMaterial(MaterialModel material) async {
    await _firestoreService.saveMaterial(material);
  }

  Future<void> saveMaterialWithCompany(
    MaterialModel material,
    String companyId,
  ) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final data = material.toMap();
    batch.set(db.collection('materials').doc(material.id), data);
    batch.set(
      db.collection('companies').doc(companyId).collection('materials').doc(material.id),
      data,
    );
    await batch.commit();
  }

  Future<void> updateMaterialFields(
    String matId,
    String companyId,
    Map<String, dynamic> data,
  ) async {
    final db = FirebaseFirestore.instance;
    await Future.wait([
      db.collection('materials').doc(matId).update(data),
      db
          .collection('companies')
          .doc(companyId)
          .collection('materials')
          .doc(matId)
          .update(data),
    ]);
  }

  Future<void> removeMaterial(String id) async {
    await _firestoreService.deleteMaterial(id);
  }

  Future<List<CategoryModel>> getCategories() async {
    return await _firestoreService.getCategories();
  }

  Future<double> getSupplierAverageRating(String supplierUid) async {
    return await _firestoreService.getSupplierAverageRating(supplierUid);
  }

  Future<List<MaterialModel>> getCompanyMaterialsBySupplier(
    String companyId,
    String supplierId,
  ) async {
    return _firestoreService.getCompanyMaterialsBySupplier(companyId, supplierId);
  }

  Future<List<MaterialModel>> getRecentCompanyMaterials(
    String companyId, {
    int limit = 4,
  }) async {
    return await _firestoreService.getRecentCompanyMaterials(companyId, limit: limit);
  }

  Future<void> archiveMaterialPriceChange({
    required String materialId,
    required double previousPrice,
    required double newPrice,
    String? supplierUid,
  }) async {
    await _firestoreService.archiveMaterialPriceChange(
      materialId: materialId,
      previousPrice: previousPrice,
      newPrice: newPrice,
      supplierUid: supplierUid,
    );
  }

  Future<void> recordInitialMaterialPrice({
    required String materialId,
    required double price,
    String? supplierUid,
  }) async {
    await _firestoreService.recordInitialMaterialPrice(
      materialId: materialId,
      price: price,
      supplierUid: supplierUid,
    );
  }

  Future<List<PriceHistoryModel>> getPriceTrendForMaterial(
    String companyId,
    String materialName, {
    int months = AppConstants.priceHistoryMonths,
  }) async {
    return _firestoreService.getCompanyMaterialPriceTrend(
      companyId: companyId,
      materialName: materialName,
      months: months,
    );
  }

  Future<List<PriceHistoryModel>> getSupplierMaterialPriceTrend({
    required String materialId,
    required String supplierUid,
    int months = AppConstants.priceHistoryMonths,
    String? companyId,
  }) async {
    return _firestoreService.getMaterialPriceHistoryForSupplier(
      materialId: materialId,
      supplierUid: supplierUid,
      months: months,
      companyId: companyId,
    );
  }
}
