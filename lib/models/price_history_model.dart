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

  PriceHistoryModel({
    required this.histId,
    required this.materialId,
    required this.supplierUid,
    required this.companyId,
    required this.price,
    this.previousPrice,
    this.changePercent,
    required this.timestamp,
  });

  factory PriceHistoryModel.fromMap(String id, Map<String, dynamic> map) => PriceHistoryModel(
    histId: id,
    materialId: map['materialId'] ?? '',
    supplierUid: map['supplierUid'] ?? '',
    companyId: map['companyId'] ?? '',
    price: (map['price'] as num?)?.toDouble() ?? 0.0,
    previousPrice: (map['previousPrice'] as num?)?.toDouble(),
    changePercent: (map['changePercent'] as num?)?.toDouble(),
    timestamp: map['timestamp'] is Timestamp 
        ? (map['timestamp'] as Timestamp).toDate() 
        : DateTime.tryParse(map['timestamp']?.toString() ?? '') ?? DateTime.now(),
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
}
