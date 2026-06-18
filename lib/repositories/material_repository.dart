import '../models/material_model.dart';
import '../models/category_model.dart';
import '../services/firestore_service.dart';

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
    // In a real app, this might filter by linked suppliers too
    return await _firestoreService.getPopularMaterials();
  }

  Future<List<MaterialModel>> getMaterialsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    return await _firestoreService.getMaterialsByIds(ids);
  }

  Future<List<MaterialModel>> searchMaterials(String query) async {
    return await _firestoreService.searchMaterials(query);
  }

  Stream<List<MaterialModel>> streamCategoryMaterials(String category, {String? companyId, Map<String, dynamic>? filters, String? sort}) {
    return _firestoreService.streamCategoryMaterials(category, companyId: companyId, filters: filters, sort: sort);
  }

  Future<List<MaterialModel>> getApprovedSuppliersForMaterial(String materialName) async {
    return await _firestoreService.getApprovedSuppliersForMaterial(materialName);
  }

  Future<void> saveMaterial(MaterialModel material) async {
    await _firestoreService.saveMaterial(material);
  }

  Future<void> removeMaterial(String id) async {
    await _firestoreService.deleteMaterial(id);
  }

  Future<List<CategoryModel>> getCategories() async {
    return await _firestoreService.getCategories();
  }
}
