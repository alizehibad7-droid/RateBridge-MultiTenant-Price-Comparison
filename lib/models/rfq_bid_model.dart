import 'package:cloud_firestore/cloud_firestore.dart';

class RfqBidModel {
  final String id;
  final String rfqId;
  final String supplierId;
  final String supplierName;
  final double bidPrice;
  final String estimatedDeliveryTime;
  final String? note;
  final DateTime createdAt;
  final double supplierRating;

  RfqBidModel({
    required this.id,
    required this.rfqId,
    required this.supplierId,
    required this.supplierName,
    required this.bidPrice,
    required this.estimatedDeliveryTime,
    this.note,
    required this.createdAt,
    this.supplierRating = 0.0,
  });

  factory RfqBidModel.fromMap(String id, Map<String, dynamic> map) {
    return RfqBidModel(
      id: id,
      rfqId: map['rfqId'] ?? '',
      supplierId: map['supplierId'] ?? '',
      supplierName: map['supplierName'] ?? '',
      bidPrice: (map['bidPrice'] as num?)?.toDouble() ?? 0.0,
      estimatedDeliveryTime: map['estimatedDeliveryTime'] ?? '',
      note: map['note'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      supplierRating: (map['supplierRating'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rfqId': rfqId,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'bidPrice': bidPrice,
      'estimatedDeliveryTime': estimatedDeliveryTime,
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'supplierRating': supplierRating,
    };
  }
}
