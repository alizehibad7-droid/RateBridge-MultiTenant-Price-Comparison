// MVVM: Model — pure Dart
import 'material_listing.dart';

class SupplierCompareModel {
  final String supplierUid;
  final String businessName;
  final double price;
  final double rating;
  final int reviewCount;
  final String city;
  final bool isVerified;
  final bool isAnomalyFlagged;
  final String materialId;
  final String materialName;
  final String unit;
  final String category;
  final String phone;
  final String? availability;
  final DateTime? priceUpdatedAt;
  final String? brand;
  final String? qualityGrade;
  final double? minOrderQuantity;

  SupplierCompareModel({
    required this.supplierUid,
    required this.businessName,
    required this.price,
    required this.rating,
    required this.city,
    required this.isVerified,
    required this.isAnomalyFlagged,
    this.reviewCount = 0,
    this.materialId = '',
    this.materialName = '',
    this.unit = '',
    this.category = '',
    this.phone = '',
    this.availability,
    this.priceUpdatedAt,
    this.brand,
    this.qualityGrade,
    this.minOrderQuantity,
  });

  double get pricePerUnit => price;
  bool get isAnomaly => isAnomalyFlagged;
  String get supplierId => supplierUid;
  String get supplierName => businessName;

  MaterialListing toMaterialListing({int stock = 1}) {
    return MaterialListing(
      id: materialId,
      materialName: materialName,
      supplierName: businessName,
      supplierId: supplierUid,
      pricePerUnit: price,
      unit: unit,
      supplierRating: rating,
      reviewCount: reviewCount,
      stock: stock,
      category: category,
      city: city,
      phone: phone,
      priceUpdatedAt: priceUpdatedAt,
      isAnomaly: isAnomalyFlagged,
      isBestValue: false,
      brand: brand,
      qualityGrade: qualityGrade,
      minOrderQuantity: minOrderQuantity,
    );
  }
}
