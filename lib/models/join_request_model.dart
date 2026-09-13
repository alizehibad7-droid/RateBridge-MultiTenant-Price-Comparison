// MVVM: Model — pure Dart
import 'package:cloud_firestore/cloud_firestore.dart';

class JoinRequestModel {
  final String reqId;
  final String supplierUid;
  final String supplierName;
  final String supplierEmail;
  final String supplierCity;
  final List<String> supplierCategories;
  final double supplierRating;
  final String companyId;
  final String? message;
  final String status; // pending|accepted|rejected
  final String? rejectionReason;
  final String initiatedBy; // 'company' | 'supplier'
  final DateTime createdAt;

  JoinRequestModel({
    required this.reqId,
    required this.supplierUid,
    required this.supplierName,
    required this.supplierEmail,
    required this.supplierCity,
    required this.supplierCategories,
    required this.supplierRating,
    required this.companyId,
    this.message,
    required this.status,
    this.rejectionReason,
    this.initiatedBy = 'supplier',
    required this.createdAt,
  });

  factory JoinRequestModel.fromMap(String id, Map<String, dynamic> map) => JoinRequestModel(
    reqId: id,
    supplierUid: map['supplierUid'] ?? '',
    supplierName: map['supplierName'] ?? map['businessName'] ?? '',
    supplierEmail: map['supplierEmail'] ?? map['email'] ?? '',
    supplierCity: map['supplierCity'] ?? map['city'] ?? '',
    supplierCategories: List<String>.from(map['supplierCategories'] ?? map['categories'] ?? []),
    supplierRating: (map['supplierRating'] as num?)?.toDouble() ?? 
                    (map['platformRating'] as num?)?.toDouble() ?? 
                    (map['rating'] as num?)?.toDouble() ?? 0.0,
    companyId: map['companyId'] ?? '',
    message: map['message'],
    status: map['status'] ?? 'pending',
    rejectionReason: map['rejectionReason'],
    initiatedBy: map['initiatedBy'] ?? 'supplier',
    createdAt: map['createdAt'] is Timestamp 
        ? (map['createdAt'] as Timestamp).toDate() 
        : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'supplierUid': supplierUid,
    'supplierName': supplierName,
    'supplierEmail': supplierEmail,
    'supplierCity': supplierCity,
    'supplierCategories': supplierCategories,
    'supplierRating': supplierRating,
    'companyId': companyId,
    'message': message,
    'status': status,
    'rejectionReason': rejectionReason,
    'initiatedBy': initiatedBy,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
