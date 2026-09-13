class MaterialListing {
  final String id;
  final String materialName;
  final String supplierName;
  final String supplierId;
  final double pricePerUnit;
  final String unit;
  final double supplierRating;
  final int reviewCount;
  final int stock;
  final String category;
  final String? city;
  final String? phone;
  final DateTime? priceUpdatedAt;
  final bool isAnomaly;
  final bool isBestValue;
  final String? brand;
  final String? qualityGrade;
  final String? description;
  final double? minOrderQuantity;
  final String? deliveryTime;
  final String? deliveryCoverageArea;
  final String? deliveryCharges;
  final bool? bulkDiscountAvailable;
  final String? bulkDiscountDetails;

  MaterialListing({
    required this.id,
    required this.materialName,
    required this.supplierName,
    required this.supplierId,
    required this.pricePerUnit,
    required this.unit,
    this.supplierRating = 0.0,
    this.reviewCount = 0,
    this.stock = 0,
    required this.category,
    this.city,
    this.phone,
    this.priceUpdatedAt,
    this.isAnomaly = false,
    this.isBestValue = false,
    this.brand,
    this.qualityGrade,
    this.description,
    this.minOrderQuantity,
    this.deliveryTime,
    this.deliveryCoverageArea,
    this.deliveryCharges,
    this.bulkDiscountAvailable,
    this.bulkDiscountDetails,
  });

  String get grade => qualityGrade ?? '';

  String? get brandGradeSubtitle {
    final parts = <String>[];
    final brandText = brand?.trim();
    final gradeText = qualityGrade?.trim();
    if (brandText != null && brandText.isNotEmpty) parts.add(brandText);
    if (gradeText != null && gradeText.isNotEmpty) parts.add(gradeText);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String? get minOrderLabel {
    final qty = minOrderQuantity;
    if (qty == null || qty <= 0) return null;
    final qtyText =
        qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toStringAsFixed(2);
    final unitText = unit.trim();
    return unitText.isEmpty
        ? 'Min. order: $qtyText'
        : 'Min. order: $qtyText $unitText';
  }

  bool get hasDeliveryInfo =>
      (deliveryTime?.trim().isNotEmpty ?? false) ||
      (deliveryCoverageArea?.trim().isNotEmpty ?? false) ||
      (deliveryCharges?.trim().isNotEmpty ?? false);

  bool get hasBulkDiscount =>
      bulkDiscountAvailable == true &&
      (bulkDiscountDetails?.trim().isNotEmpty ?? false);

  MaterialListing copyWith({
    String? id,
    String? materialName,
    String? supplierName,
    String? supplierId,
    double? pricePerUnit,
    String? unit,
    double? supplierRating,
    int? reviewCount,
    int? stock,
    String? category,
    String? city,
    String? phone,
    DateTime? priceUpdatedAt,
    bool? isAnomaly,
    bool? isBestValue,
    String? brand,
    String? qualityGrade,
    String? description,
    double? minOrderQuantity,
    String? deliveryTime,
    String? deliveryCoverageArea,
    String? deliveryCharges,
    bool? bulkDiscountAvailable,
    String? bulkDiscountDetails,
  }) {
    return MaterialListing(
      id: id ?? this.id,
      materialName: materialName ?? this.materialName,
      supplierName: supplierName ?? this.supplierName,
      supplierId: supplierId ?? this.supplierId,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      unit: unit ?? this.unit,
      supplierRating: supplierRating ?? this.supplierRating,
      reviewCount: reviewCount ?? this.reviewCount,
      stock: stock ?? this.stock,
      category: category ?? this.category,
      city: city ?? this.city,
      phone: phone ?? this.phone,
      priceUpdatedAt: priceUpdatedAt ?? this.priceUpdatedAt,
      isAnomaly: isAnomaly ?? this.isAnomaly,
      isBestValue: isBestValue ?? this.isBestValue,
      brand: brand ?? this.brand,
      qualityGrade: qualityGrade ?? this.qualityGrade,
      description: description ?? this.description,
      minOrderQuantity: minOrderQuantity ?? this.minOrderQuantity,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      deliveryCoverageArea: deliveryCoverageArea ?? this.deliveryCoverageArea,
      deliveryCharges: deliveryCharges ?? this.deliveryCharges,
      bulkDiscountAvailable:
          bulkDiscountAvailable ?? this.bulkDiscountAvailable,
      bulkDiscountDetails: bulkDiscountDetails ?? this.bulkDiscountDetails,
    );
  }
}
