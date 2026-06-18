// MVVM: Model — pure Dart
class SupplierCompareModel {
  final String supplierUid;
  final String businessName;
  final double price;
  final double rating;
  final String city;
  final bool isVerified;
  final bool isAnomalyFlagged;

  SupplierCompareModel({
    required this.supplierUid,
    required this.businessName,
    required this.price,
    required this.rating,
    required this.city,
    required this.isVerified,
    required this.isAnomalyFlagged,
  });
}
