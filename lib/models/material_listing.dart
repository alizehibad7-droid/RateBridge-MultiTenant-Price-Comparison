class MaterialListing {
  final String id;
  final String materialName;
  final String supplierName;
  final String supplierId;
  final double pricePerUnit;
  final String unit;
  final double supplierRating;
  final int stock;
  final String category;

  MaterialListing({
    required this.id,
    required this.materialName,
    required this.supplierName,
    required this.supplierId,
    required this.pricePerUnit,
    required this.unit,
    this.supplierRating = 0.0,
    this.stock = 0,
    required this.category,
  });
}
