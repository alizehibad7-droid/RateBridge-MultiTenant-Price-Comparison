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
  final String? companyType;
  final int? yearsInOperation;
  final String? ceoFullName;
  final String? designation;
  final String? cnicNumber;
  final String? cnicFrontUrl;
  final String? cnicBackUrl;
  final String? estimatedMonthlyVolume;
  final int? activeSitesCount;
  final String? registrationCertUrl;
  final String? officePhotoUrl;
  final String? rejectionReason;

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
    this.companyType,
    this.yearsInOperation,
    this.ceoFullName,
    this.designation,
    this.cnicNumber,
    this.cnicFrontUrl,
    this.cnicBackUrl,
    this.estimatedMonthlyVolume,
    this.activeSitesCount,
    this.registrationCertUrl,
    this.officePhotoUrl,
    this.rejectionReason,
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
    String? companyType,
    int? yearsInOperation,
    String? ceoFullName,
    String? designation,
    String? cnicNumber,
    String? cnicFrontUrl,
    String? cnicBackUrl,
    String? estimatedMonthlyVolume,
    int? activeSitesCount,
    String? registrationCertUrl,
    String? officePhotoUrl,
    String? rejectionReason,
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
      companyType: companyType ?? this.companyType,
      yearsInOperation: yearsInOperation ?? this.yearsInOperation,
      ceoFullName: ceoFullName ?? this.ceoFullName,
      designation: designation ?? this.designation,
      cnicNumber: cnicNumber ?? this.cnicNumber,
      cnicFrontUrl: cnicFrontUrl ?? this.cnicFrontUrl,
      cnicBackUrl: cnicBackUrl ?? this.cnicBackUrl,
      estimatedMonthlyVolume:
          estimatedMonthlyVolume ?? this.estimatedMonthlyVolume,
      activeSitesCount: activeSitesCount ?? this.activeSitesCount,
      registrationCertUrl: registrationCertUrl ?? this.registrationCertUrl,
      officePhotoUrl: officePhotoUrl ?? this.officePhotoUrl,
      rejectionReason: rejectionReason ?? this.rejectionReason,
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
      if (companyType != null) 'companyType': companyType,
      if (yearsInOperation != null) 'yearsInOperation': yearsInOperation,
      if (ceoFullName != null) 'ceoFullName': ceoFullName,
      if (designation != null) 'designation': designation,
      if (cnicNumber != null) 'cnicNumber': cnicNumber,
      if (cnicFrontUrl != null) 'cnicFrontUrl': cnicFrontUrl,
      if (cnicBackUrl != null) 'cnicBackUrl': cnicBackUrl,
      if (estimatedMonthlyVolume != null)
        'estimatedMonthlyVolume': estimatedMonthlyVolume,
      if (activeSitesCount != null) 'activeSitesCount': activeSitesCount,
      if (registrationCertUrl != null)
        'registrationCertUrl': registrationCertUrl,
      if (officePhotoUrl != null) 'officePhotoUrl': officePhotoUrl,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
    };
  }

  factory CompanyModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic date) {
      if (date == null) return DateTime.now();
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.tryParse(date) ?? DateTime.now();
      return DateTime.now();
    }

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
      companyType: map['companyType'] as String?,
      yearsInOperation: (map['yearsInOperation'] as num?)?.toInt(),
      ceoFullName: map['ceoFullName'] as String?,
      designation: map['designation'] as String?,
      cnicNumber: map['cnicNumber'] as String?,
      cnicFrontUrl: map['cnicFrontUrl'] as String?,
      cnicBackUrl: map['cnicBackUrl'] as String?,
      estimatedMonthlyVolume: map['estimatedMonthlyVolume'] as String?,
      activeSitesCount: (map['activeSitesCount'] as num?)?.toInt(),
      registrationCertUrl: map['registrationCertUrl'] as String?,
      officePhotoUrl: map['officePhotoUrl'] as String?,
      rejectionReason: map['rejectionReason'] as String?,
    );
  }
}
