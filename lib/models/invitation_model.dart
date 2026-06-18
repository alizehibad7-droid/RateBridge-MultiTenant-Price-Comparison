// MVVM: Model — pure Dart
import 'package:cloud_firestore/cloud_firestore.dart';

class InvitationModel {
  final String token;
  final String companyId;
  final String ceoUid;
  final String? supplierUid;
  final String? email;
  final String? role;
  final String companyName;
  final String status; // pending|accepted|rejected|expired
  final DateTime expiresAt;
  final DateTime createdAt;

  InvitationModel({
    required this.token,
    required this.companyId,
    required this.ceoUid,
    this.supplierUid,
    this.email,
    this.role,
    required this.companyName,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
  });

  factory InvitationModel.fromMap(String token, Map<String, dynamic> map) => InvitationModel(
    token: token,
    companyId: map['companyId'] ?? '',
    ceoUid: map['ceoUid'] ?? '',
    supplierUid: map['supplierUid'] as String?,
    email: map['email'] as String?,
    role: map['role'] as String?,
    companyName: map['companyName'] ?? '',
    status: map['status'] ?? 'pending',
    expiresAt: map['expiresAt'] is Timestamp 
        ? (map['expiresAt'] as Timestamp).toDate() 
        : DateTime.tryParse(map['expiresAt']?.toString() ?? '') ?? DateTime.now(),
    createdAt: map['createdAt'] is Timestamp 
        ? (map['createdAt'] as Timestamp).toDate() 
        : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'companyId': companyId,
    'ceoUid': ceoUid,
    'supplierUid': supplierUid,
    'email': email,
    'role': role,
    'companyName': companyName,
    'status': status,
    'expiresAt': Timestamp.fromDate(expiresAt),
    'createdAt': FieldValue.serverTimestamp(),
  };

  InvitationModel copyWith({
    String? token,
    String? companyId,
    String? ceoUid,
    String? supplierUid,
    String? email,
    String? role,
    String? companyName,
    String? status,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) {
    return InvitationModel(
      token: token ?? this.token,
      companyId: companyId ?? this.companyId,
      ceoUid: ceoUid ?? this.ceoUid,
      supplierUid: supplierUid ?? this.supplierUid,
      email: email ?? this.email,
      role: role ?? this.role,
      companyName: companyName ?? this.companyName,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
