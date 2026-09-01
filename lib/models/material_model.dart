// Pure Dart Model for Materials conforming with Rule 5
import 'package:cloud_firestore/cloud_firestore.dart';

class MaterialModel {
  final String id;
  final String name;
  final String category; // 'Steel' | 'Cement' | 'Aggregates' | 'Sand'
  final double pricePerUnit;
  final String unit; // 'Metric Tons' | 'Bags' | 'Cft'
  final String specifications;
  final String qualityGrade; // e.g., 'Grade-60', 'OPC 43.5'
  final String supplierId;
  final String supplierName;
  final bool isCertified; // Pakistan Engineering Council or ASTM standards
  final String originCity;
  final String? profileImageUrl;
  final String? brand;
  final String? stockStatus;
  final double? minOrderQuantity;
  final String? deliveryTime;
  final String? description;
  final bool? bulkDiscountAvailable;
  final String? bulkDiscountDetails;
  final String? deliveryCoverageArea;
  final String? deliveryCharges;
  final DateTime? createdAt;

  MaterialModel({
    required this.id,
    required this.name,
    required this.category,
    required this.pricePerUnit,
    required this.unit,
    required this.specifications,
    required this.qualityGrade,
    required this.supplierId,
    required this.supplierName,
    required this.isCertified,
    required this.originCity,
    this.profileImageUrl,
    this.brand,
    this.stockStatus,
    this.minOrderQuantity,
    this.deliveryTime,
    this.description,
    this.bulkDiscountAvailable,
    this.bulkDiscountDetails,
    this.deliveryCoverageArea,
    this.deliveryCharges,
    this.createdAt,
  });

  // Getters to support UI components
  String get city => originCity;
  String get grade => qualityGrade;

  MaterialModel copyWith({
    String? id,
    String? name,
    String? category,
    double? pricePerUnit,
    String? unit,
    String? specifications,
    String? qualityGrade,
    String? supplierId,
    String? supplierName,
    bool? isCertified,
    String? originCity,
    String? profileImageUrl,
    String? brand,
    String? stockStatus,
    double? minOrderQuantity,
    String? deliveryTime,
    String? description,
    bool? bulkDiscountAvailable,
    String? bulkDiscountDetails,
    String? deliveryCoverageArea,
    String? deliveryCharges,
    DateTime? createdAt,
  }) {
    return MaterialModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      unit: unit ?? this.unit,
      specifications: specifications ?? this.specifications,
      qualityGrade: qualityGrade ?? this.qualityGrade,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      isCertified: isCertified ?? this.isCertified,
      originCity: originCity ?? this.originCity,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      brand: brand ?? this.brand,
      stockStatus: stockStatus ?? this.stockStatus,
      minOrderQuantity: minOrderQuantity ?? this.minOrderQuantity,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      description: description ?? this.description,
      bulkDiscountAvailable:
          bulkDiscountAvailable ?? this.bulkDiscountAvailable,
      bulkDiscountDetails: bulkDiscountDetails ?? this.bulkDiscountDetails,
      deliveryCoverageArea:
          deliveryCoverageArea ?? this.deliveryCoverageArea,
      deliveryCharges: deliveryCharges ?? this.deliveryCharges,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'pricePerUnit': pricePerUnit,
      'unit': unit,
      'specifications': specifications,
      'qualityGrade': qualityGrade,
      'supplierId': supplierId,
      'supplierUid': supplierId,
      'supplierName': supplierName,
      'isCertified': isCertified,
      'originCity': originCity,
      'profileImageUrl': profileImageUrl,
      'brand': brand,
      if (stockStatus != null) 'stockStatus': stockStatus,
      if (minOrderQuantity != null) 'minOrderQuantity': minOrderQuantity,
      if (deliveryTime != null) 'deliveryTime': deliveryTime,
      if (description != null) 'description': description,
      if (bulkDiscountAvailable != null)
        'bulkDiscountAvailable': bulkDiscountAvailable,
      if (bulkDiscountDetails != null)
        'bulkDiscountDetails': bulkDiscountDetails,
      if (deliveryCoverageArea != null)
        'deliveryCoverageArea': deliveryCoverageArea,
      if (deliveryCharges != null) 'deliveryCharges': deliveryCharges,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }

  /// Reads the material photo URL from Firestore, including older field names.
  static String? imageUrlFromMap(Map<String, dynamic> map) {
    String? from(dynamic value) {
      if (value is String) {
        final trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      return null;
    }

    final direct = from(map['profileImageUrl']) ??
        from(map['imageUrl']) ??
        from(map['photoUrl']) ??
        from(map['image']);
    if (direct != null) return direct;

    final images = map['images'];
    if (images is List && images.isNotEmpty) {
      return from(images.first);
    }
    return null;
  }

  factory MaterialModel.fromMap(Map<String, dynamic> map) {
    return MaterialModel(
      id: (map['id'] ?? '') as String,
      name: (map['name'] ?? map['materialName'] ?? '') as String,
      category: (map['category'] ?? '') as String,
      pricePerUnit: (map['pricePerUnit'] as num? ?? 0.0).toDouble(),
      unit: (map['unit'] ?? '') as String,
      specifications: (map['specifications'] ?? '') as String,
      qualityGrade: (map['qualityGrade'] ?? '') as String,
      supplierId: (map['supplierId'] ?? map['supplierUid'] ?? '') as String,
      supplierName: (map['supplierName'] ?? '') as String,
      isCertified: (map['isCertified'] ?? false) as bool,
      originCity: (map['originCity'] ?? '') as String,
      profileImageUrl: imageUrlFromMap(map),
      brand: map['brand'] as String?,
      stockStatus: map['stockStatus'] as String?,
      minOrderQuantity: (map['minOrderQuantity'] as num?)?.toDouble(),
      deliveryTime: map['deliveryTime'] as String?,
      description: map['description'] as String?,
      bulkDiscountAvailable: map['bulkDiscountAvailable'] as bool?,
      bulkDiscountDetails: map['bulkDiscountDetails'] as String?,
      deliveryCoverageArea: map['deliveryCoverageArea'] as String?,
      deliveryCharges: map['deliveryCharges'] as String?,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? ''),
    );
  }
}
