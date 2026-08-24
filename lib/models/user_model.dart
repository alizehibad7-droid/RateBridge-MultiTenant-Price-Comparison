import 'package:cloud_firestore/cloud_firestore.dart';

// Pure Dart Model - No Flutter Imports as per Rule 5
class UserModel {
  final String uid;
  final String email;
  final String name;
  final String role; // 'CEO' | 'field_user' | 'Supplier' | 'Admin'
  final String companyId;
  final String phone;
  final String city;
  final String? address;
  final String? cnic;
  final String? jobTitle;
  final String? assignedSite;
  final String? businessType;
  final String? profileImageUrl;
  final List<String> fcmTokens;
  final String? status; // 'pending' | 'active' | 'rejected' | 'suspended'
  final bool approved;
  final String? rejectionReason;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final List<String>? declaredCategories;
  final double? rating;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.companyId,
    required this.phone,
    required this.city,
    this.address,
    this.cnic,
    this.jobTitle,
    this.assignedSite,
    this.businessType,
    this.profileImageUrl,
    this.fcmTokens = const [],
    this.status = 'active',
    this.approved = false,
    this.rejectionReason,
    this.createdBy,
    required this.createdAt,
    this.approvedAt,
    this.declaredCategories,
    this.rating,
  });

  // Getters to fix compilation errors in views and viewmodels
  String? get profilePicture => profileImageUrl;
  String get fullName => name;
  DateTime? get joinedAt => createdAt;
  String? get cnicNumber => cnic;
  
  // Legacy support for single token getter
  String? get fcmToken => fcmTokens.isNotEmpty ? fcmTokens.first : null;

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? role,
    String? companyId,
    String? phone,
    String? city,
    String? address,
    String? cnic,
    String? jobTitle,
    String? assignedSite,
    String? businessType,
    String? profileImageUrl,
    String? profilePicture,
    List<String>? fcmTokens,
    String? fcmToken, // Support legacy singular name in copyWith
    String? status,
    bool? approved,
    String? rejectionReason,
    String? createdBy,
    DateTime? createdAt,
    DateTime? approvedAt,
    List<String>? declaredCategories,
    double? rating,
  }) {
    List<String>? tokens = fcmTokens;
    if (fcmToken != null) {
      tokens = [fcmToken];
    }

    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      companyId: companyId ?? this.companyId,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      address: address ?? this.address,
      cnic: cnic ?? this.cnic,
      jobTitle: jobTitle ?? this.jobTitle,
      assignedSite: assignedSite ?? this.assignedSite,
      businessType: businessType ?? this.businessType,
      profileImageUrl: profilePicture ?? profileImageUrl ?? this.profileImageUrl,
      fcmTokens: tokens ?? this.fcmTokens,
      status: status ?? this.status,
      approved: approved ?? this.approved,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      declaredCategories: declaredCategories ?? this.declaredCategories,
      rating: rating ?? this.rating,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'role': role,
      'companyId': companyId,
      'phone': phone,
      'city': city,
      'address': address,
      'cnic': cnic,
      if (cnic != null) 'cnicNumber': cnic,
      if (jobTitle != null) 'jobTitle': jobTitle,
      if (assignedSite != null) 'assignedSite': assignedSite,
      'businessType': businessType,
      'profileImageUrl': profileImageUrl,
      'fcmTokens': fcmTokens,
      'status': status,
      'approved': approved,
      'rejectionReason': rejectionReason,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'declaredCategories': declaredCategories,
      'rating': rating,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic date) {
      if (date == null) return DateTime.now();
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.tryParse(date) ?? DateTime.now();
      return DateTime.now();
    }

    dynamic tokensData = map['fcmTokens'] ?? map['fcmToken'];
    List<String> tokens = [];
    if (tokensData is List) {
      tokens = List<String>.from(tokensData);
    } else if (tokensData is String && tokensData.isNotEmpty) {
      tokens = [tokensData];
    }

    return UserModel(
      uid: (map['uid'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      role: (map['role'] ?? '').toString().trim(),
      companyId: (map['companyId'] ?? '') as String,
      phone: (map['phone'] ?? map['phoneNumber'] ?? '') as String,
      city: (map['city'] ?? '') as String,
      address: map['address'] as String?,
      cnic: (map['cnicNumber'] ?? map['cnic']) as String?,
      jobTitle: map['jobTitle'] as String?,
      assignedSite: map['assignedSite'] as String?,
      businessType: map['businessType'] as String?,
      profileImageUrl: map['profileImageUrl'] as String?,
      fcmTokens: tokens,
      status: (map['status'] as String? ?? 'active').toLowerCase().trim(),
      approved: map['approved'] ?? false,
      rejectionReason: map['rejectionReason'] as String?,
      createdBy: map['createdBy'] as String?,
      createdAt: parseDate(map['createdAt']),
      approvedAt: map['approvedAt'] != null ? parseDate(map['approvedAt']) : null,
      declaredCategories: map['declaredCategories'] is List
          ? List<String>.from(map['declaredCategories'])
          : null,
      rating: (map['rating'] as num?)?.toDouble(),
    );
  }
}
