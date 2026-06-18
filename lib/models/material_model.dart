// Pure Dart Model for Materials conforming with Rule 5
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
      'supplierName': supplierName,
      'isCertified': isCertified,
      'originCity': originCity,
      'profileImageUrl': profileImageUrl,
      'brand': brand,
    };
  }

  factory MaterialModel.fromMap(Map<String, dynamic> map) {
    return MaterialModel(
      id: (map['id'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      category: (map['category'] ?? '') as String,
      pricePerUnit: (map['pricePerUnit'] as num? ?? 0.0).toDouble(),
      unit: (map['unit'] ?? '') as String,
      specifications: (map['specifications'] ?? '') as String,
      qualityGrade: (map['qualityGrade'] ?? '') as String,
      supplierId: (map['supplierId'] ?? '') as String,
      supplierName: (map['supplierName'] ?? '') as String,
      isCertified: (map['isCertified'] ?? false) as bool,
      originCity: (map['originCity'] ?? '') as String,
      profileImageUrl: map['profileImageUrl'] as String?,
      brand: map['brand'] as String?,
    );
  }
}
