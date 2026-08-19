import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentType { subscription, commission }

class PaymentProofModel {
  final String id;
  final String payerId;
  final String payerName;
  final String payerRole;
  final double amountExpected;
  final double amountDetected;
  final String transactionIdDetected;
  final String method;
  final String screenshotUrl;
  final String status; // pending_review | approved | rejected
  final String type; // subscription | commission
  final String? planKey;
  final List<String>? relatedTransactions;
  final bool isAiVerified;
  final String? adminNotes;
  final DateTime createdAt;

  PaymentProofModel({
    required this.id,
    required this.payerId,
    required this.payerName,
    required this.payerRole,
    required this.amountExpected,
    required this.amountDetected,
    required this.transactionIdDetected,
    required this.method,
    required this.screenshotUrl,
    required this.status,
    required this.type,
    this.planKey,
    this.relatedTransactions,
    required this.isAiVerified,
    this.adminNotes,
    required this.createdAt,
  });

  factory PaymentProofModel.fromMap(String id, Map<String, dynamic> map) {
    return PaymentProofModel(
      id: id,
      payerId: map['payerId'] ?? '',
      payerName: map['payerName'] ?? '',
      payerRole: map['payerRole'] ?? '',
      amountExpected: (map['amountExpected'] as num?)?.toDouble() ?? 0.0,
      amountDetected: (map['amountDetected'] as num?)?.toDouble() ?? 0.0,
      transactionIdDetected: map['transactionIdDetected'] ?? '',
      method: map['method'] ?? '',
      screenshotUrl: map['screenshotUrl'] ?? '',
      status: map['status'] ?? 'pending_review',
      type: map['type'] ?? '',
      planKey: map['planKey'],
      relatedTransactions: map['relatedTransactions'] != null 
          ? List<String>.from(map['relatedTransactions']) 
          : null,
      isAiVerified: map['isAiVerified'] ?? false,
      adminNotes: map['adminNotes'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
