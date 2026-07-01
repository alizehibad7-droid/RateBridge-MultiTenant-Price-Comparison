import 'package:cloud_firestore/cloud_firestore.dart';

/// CEO-submitted manual subscription payment awaiting admin review.
class SubscriptionPaymentModel {
  final String id;
  final String companyId;
  final String companyName;
  final String submittedByUid;
  final String plan;
  final int amount;
  final String paymentProofUrl;
  final String status; // pending | approved | rejected
  final DateTime submittedAt;
  final String? rejectionReason;
  final String? reviewedByUid;
  final DateTime? reviewedAt;

  const SubscriptionPaymentModel({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.submittedByUid,
    required this.plan,
    required this.amount,
    required this.paymentProofUrl,
    required this.status,
    required this.submittedAt,
    this.rejectionReason,
    this.reviewedByUid,
    this.reviewedAt,
  });

  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';

  String get planLabel {
    switch (plan) {
      case 'basic':
        return 'Basic';
      case 'premium':
        return 'Premium';
      default:
        return plan;
    }
  }

  factory SubscriptionPaymentModel.fromMap(String id, Map<String, dynamic> map) {
    return SubscriptionPaymentModel(
      id: id,
      companyId: map['companyId'] as String? ?? '',
      companyName: map['companyName'] as String? ?? '',
      submittedByUid: map['submittedByUid'] as String? ?? '',
      plan: map['plan'] as String? ?? '',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      paymentProofUrl: map['paymentProofUrl'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      submittedAt: _parseDate(map['submittedAt']),
      rejectionReason: map['rejectionReason'] as String?,
      reviewedByUid: map['reviewedByUid'] as String?,
      reviewedAt: map['reviewedAt'] != null ? _parseDate(map['reviewedAt']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'companyId': companyId,
        'companyName': companyName,
        'submittedByUid': submittedByUid,
        'plan': plan,
        'amount': amount,
        'paymentProofUrl': paymentProofUrl,
        'status': status,
        'submittedAt': FieldValue.serverTimestamp(),
      };

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
