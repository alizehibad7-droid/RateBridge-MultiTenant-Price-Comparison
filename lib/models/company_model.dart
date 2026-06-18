import 'package:cloud_firestore/cloud_firestore.dart';

// Pure Dart Model with Firestore-safe parsing
class CompanyModel {
  final String id;
  final String name;
  final String registrationNumber;
  final String address;
  final String city;
  final String phone;
  final String? logoUrl;
  final String status; // 'active' | 'pending' | 'suspended' | 'rejected'
  final DateTime createdAt;
  final String? inviteCode;
  final String? plan; // 'free' | 'basic' | 'premium'
  final bool? aiEnabled;
  final String? ceoUid;

  CompanyModel({
    required this.id,
    required this.name,
    required this.registrationNumber,
    required this.address,
    this.city = '',
    this.phone = '',
    this.logoUrl,
    required this.status,
    required this.createdAt,
    this.inviteCode,
    this.plan = 'free',
    this.aiEnabled = false,
    this.ceoUid,
  });

  CompanyModel copyWith({
    String? id,
    String? name,
    String? registrationNumber,
    String? address,
    String? city,
    String? phone,
    String? logoUrl,
    String? status,
    DateTime? createdAt,
    String? inviteCode,
    String? plan,
    bool? aiEnabled,
    String? ceoUid,
  }) {
    return CompanyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      address: address ?? this.address,
      city: city ?? this.city,
      phone: phone ?? this.phone,
      logoUrl: logoUrl ?? this.logoUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      inviteCode: inviteCode ?? this.inviteCode,
      plan: plan ?? this.plan,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      ceoUid: ceoUid ?? this.ceoUid,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'registrationNumber': registrationNumber,
      'address': address,
      'city': city,
      'phone': phone,
      'logoUrl': logoUrl,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'inviteCode': inviteCode,
      'plan': plan,
      'aiEnabled': aiEnabled,
      'ceoUid': ceoUid,
    };
  }

  factory CompanyModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic date) {
      if (date == null) return DateTime.now();
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.tryParse(date) ?? DateTime.now();
      return DateTime.now();
    }

    // Robust field mapping to handle both "name"/"companyName" and "ceoUid"/"ownerUid"
    return CompanyModel(
      id: (map['id'] ?? '') as String,
      name: (map['name'] ?? map['companyName'] ?? 'Unknown Company') as String,
      registrationNumber: (map['registrationNumber'] ?? '') as String,
      address: (map['address'] ?? '') as String,
      city: (map['city'] ?? '') as String,
      phone: (map['phone'] ?? '') as String,
      logoUrl: map['logoUrl'] as String?,
      status: (map['status'] ?? 'pending').toString().toLowerCase(),
      createdAt: parseDate(map['createdAt']),
      inviteCode: map['inviteCode'] as String?,
      plan: map['plan'] as String? ?? 'free',
      aiEnabled: map['aiEnabled'] as bool? ?? false,
      ceoUid: (map['ceoUid'] ?? map['ownerUid']) as String?,
    );
  }
}
