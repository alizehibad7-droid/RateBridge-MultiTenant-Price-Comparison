// MVVM: Model — pure Dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String txId;
  final String orderId;
  final String companyId;
  final String supplierUid;
  final double totalAmount;
  final double commissionRate; // always 0.02
  final double commissionAmount;
  final double supplierEarning;
  final String status; // settled
  final DateTime createdAt;

  const TransactionModel({
    required this.txId,
    required this.orderId,
    required this.companyId,
    required this.supplierUid,
    required this.totalAmount,
    required this.commissionRate,
    required this.commissionAmount,
    required this.supplierEarning,
    required this.status,
    required this.createdAt,
  });

  factory TransactionModel.fromMap(String id, Map<String, dynamic> map) => TransactionModel(
    txId: id,
    orderId: map['orderId'] ?? '',
    companyId: map['companyId'] ?? '',
    supplierUid: map['supplierUid'] ?? '',
    totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
    commissionRate: (map['commissionRate'] as num?)?.toDouble() ?? 0.02,
    commissionAmount: (map['commissionAmount'] as num?)?.toDouble() ?? 0.0,
    supplierEarning: (map['supplierEarning'] as num?)?.toDouble() ?? 0.0,
    status: map['status'] ?? 'settled',
    createdAt: map['createdAt'] is Timestamp 
        ? (map['createdAt'] as Timestamp).toDate() 
        : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'orderId': orderId,
    'companyId': companyId,
    'supplierUid': supplierUid,
    'totalAmount': totalAmount,
    'commissionRate': commissionRate,
    'commissionAmount': commissionAmount,
    'supplierEarning': supplierEarning,
    'status': status,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

class MonthlyEarning {
  final String month; // YYYY-MM
  final double gross;
  final double commission;
  final double net;
  final int orderCount;

  const MonthlyEarning({
    required this.month,
    required this.gross,
    required this.commission,
    required this.net,
    required this.orderCount,
  });

  factory MonthlyEarning.fromMap(String month, Map<String, dynamic> map) => MonthlyEarning(
    month: month,
    gross: (map['gross'] as num?)?.toDouble() ?? 0.0,
    commission: (map['commission'] as num?)?.toDouble() ?? 0.0,
    net: (map['net'] as num?)?.toDouble() ?? 0.0,
    orderCount: (map['orderCount'] as num?)?.toInt() ?? 0,
  );
}
