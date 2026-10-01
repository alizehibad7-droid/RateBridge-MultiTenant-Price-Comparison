// MVVM: Model — pure Dart
import 'package:cloud_firestore/cloud_firestore.dart';

class PriceHistoryModel {
  final String histId;
  final String materialId;
  final String supplierUid;
  final String companyId;
  final double price;
  final double? previousPrice;
  final double? changePercent;
  final DateTime timestamp;

  /// Display-only (resolved in ViewModel; not required on Firestore docs).
  final String? supplierName;

  /// Display-only material label for tooltips.
  final String? materialName;

  PriceHistoryModel({
    required this.histId,
    required this.materialId,
    required this.supplierUid,
    required this.companyId,
    required this.price,
    this.previousPrice,
    this.changePercent,
    required this.timestamp,
    this.supplierName,
    this.materialName,
  });

  factory PriceHistoryModel.fromMap(String id, Map<String, dynamic> map) =>
      PriceHistoryModel(
        histId: id,
        materialId: map['materialId'] ?? '',
        supplierUid: map['supplierUid'] ?? '',
        companyId: map['companyId'] ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0.0,
        previousPrice: (map['previousPrice'] as num?)?.toDouble(),
        changePercent: (map['changePercent'] as num?)?.toDouble(),
        timestamp: map['timestamp'] is Timestamp
            ? (map['timestamp'] as Timestamp).toDate()
            : map['recordedAt'] is Timestamp
                ? (map['recordedAt'] as Timestamp).toDate()
                : DateTime.tryParse(
                      map['timestamp']?.toString() ??
                          map['recordedAt']?.toString() ??
                          '',
                    ) ??
                    DateTime.now(),
        supplierName: (map['supplierName'] as String?)?.trim(),
        materialName: (map['materialName'] as String?)?.trim(),
      );

  Map<String, dynamic> toMap() => {
        'materialId': materialId,
        'supplierUid': supplierUid,
        'companyId': companyId,
        'price': price,
        'previousPrice': previousPrice,
        'changePercent': changePercent,
        'timestamp': FieldValue.serverTimestamp(),
      };

  PriceHistoryModel copyWith({
    String? histId,
    String? materialId,
    String? supplierUid,
    String? companyId,
    double? price,
    double? previousPrice,
    double? changePercent,
    DateTime? timestamp,
    String? supplierName,
    String? materialName,
  }) {
    return PriceHistoryModel(
      histId: histId ?? this.histId,
      materialId: materialId ?? this.materialId,
      supplierUid: supplierUid ?? this.supplierUid,
      companyId: companyId ?? this.companyId,
      price: price ?? this.price,
      previousPrice: previousPrice ?? this.previousPrice,
      changePercent: changePercent ?? this.changePercent,
      timestamp: timestamp ?? this.timestamp,
      supplierName: supplierName ?? this.supplierName,
      materialName: materialName ?? this.materialName,
    );
  }

  String get displaySupplierName {
    final name = supplierName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    return 'Supplier information unavailable';
  }

  String get displayMaterialName {
    final name = materialName?.trim() ?? '';
    if (name.isNotEmpty) return name;
    return 'Material';
  }
}
