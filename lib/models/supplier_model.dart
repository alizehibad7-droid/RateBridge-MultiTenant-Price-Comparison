// Pure Dart Model
class SupplierModel {
  final String id;
  final String name;
  final String email;
  final String materialType;
  final String contact;
  final String status; // 'Active' | 'Under Review' | 'pending'
  final double rating;
  final int activeContracts;
  final double contractValue;
  final int leadTimeDays;
  final String city;
  final bool isVerified;
  final List<String> categories;
  final String? paymentDetails;
  final String? businessType;
  final int? yearsInBusiness;
  final String? businessRegistrationNumber;
  final String? ownerFullName;
  final String? cnicNumber;
  final String? cnicFrontUrl;
  final String? cnicBackUrl;
  final String? businessAddress;
  final List<String> deliveryCoverageAreas;
  final String? shopPhotoUrl;
  final String? businessLicenseUrl;
  final String? certificationUrl;
  final List<String> declaredCategories;
  final String? rejectionReason;
  final bool commissionRestricted;
  final String? commissionRestrictionReason;
  final double commissionOutstandingAmount;
  final int commissionOldestUnsettledDays;
  final String commissionRestrictionOverride;

  SupplierModel({
    required this.id,
    required this.name,
    required this.email,
    required this.materialType,
    required this.contact,
    required this.status,
    required this.rating,
    required this.activeContracts,
    required this.contractValue,
    required this.leadTimeDays,
    required this.city,
    this.isVerified = false,
    this.categories = const [],
    this.paymentDetails,
    this.businessType,
    this.yearsInBusiness,
    this.businessRegistrationNumber,
    this.ownerFullName,
    this.cnicNumber,
    this.cnicFrontUrl,
    this.cnicBackUrl,
    this.businessAddress,
    this.deliveryCoverageAreas = const [],
    this.shopPhotoUrl,
    this.businessLicenseUrl,
    this.certificationUrl,
    this.declaredCategories = const [],
    this.rejectionReason,
    this.commissionRestricted = false,
    this.commissionRestrictionReason,
    this.commissionOutstandingAmount = 0,
    this.commissionOldestUnsettledDays = 0,
    this.commissionRestrictionOverride = 'none',
  });

  SupplierModel copyWith({
    String? id,
    String? name,
    String? email,
    String? materialType,
    String? contact,
    String? status,
    double? rating,
    int? activeContracts,
    double? contractValue,
    int? leadTimeDays,
    String? city,
    bool? isVerified,
    List<String>? categories,
    String? paymentDetails,
    String? businessType,
    int? yearsInBusiness,
    String? businessRegistrationNumber,
    String? ownerFullName,
    String? cnicNumber,
    String? cnicFrontUrl,
    String? cnicBackUrl,
    String? businessAddress,
    List<String>? deliveryCoverageAreas,
    String? shopPhotoUrl,
    String? businessLicenseUrl,
    String? certificationUrl,
    List<String>? declaredCategories,
    String? rejectionReason,
    bool? commissionRestricted,
    String? commissionRestrictionReason,
    double? commissionOutstandingAmount,
    int? commissionOldestUnsettledDays,
    String? commissionRestrictionOverride,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      materialType: materialType ?? this.materialType,
      contact: contact ?? this.contact,
      status: status ?? this.status,
      rating: rating ?? this.rating,
      activeContracts: activeContracts ?? this.activeContracts,
      contractValue: contractValue ?? this.contractValue,
      leadTimeDays: leadTimeDays ?? this.leadTimeDays,
      city: city ?? this.city,
      isVerified: isVerified ?? this.isVerified,
      categories: categories ?? this.categories,
      paymentDetails: paymentDetails ?? this.paymentDetails,
      businessType: businessType ?? this.businessType,
      yearsInBusiness: yearsInBusiness ?? this.yearsInBusiness,
      businessRegistrationNumber:
          businessRegistrationNumber ?? this.businessRegistrationNumber,
      ownerFullName: ownerFullName ?? this.ownerFullName,
      cnicNumber: cnicNumber ?? this.cnicNumber,
      cnicFrontUrl: cnicFrontUrl ?? this.cnicFrontUrl,
      cnicBackUrl: cnicBackUrl ?? this.cnicBackUrl,
      businessAddress: businessAddress ?? this.businessAddress,
      deliveryCoverageAreas:
          deliveryCoverageAreas ?? this.deliveryCoverageAreas,
      shopPhotoUrl: shopPhotoUrl ?? this.shopPhotoUrl,
      businessLicenseUrl: businessLicenseUrl ?? this.businessLicenseUrl,
      certificationUrl: certificationUrl ?? this.certificationUrl,
      declaredCategories: declaredCategories ?? this.declaredCategories,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      commissionRestricted: commissionRestricted ?? this.commissionRestricted,
      commissionRestrictionReason:
          commissionRestrictionReason ?? this.commissionRestrictionReason,
      commissionOutstandingAmount:
          commissionOutstandingAmount ?? this.commissionOutstandingAmount,
      commissionOldestUnsettledDays:
          commissionOldestUnsettledDays ?? this.commissionOldestUnsettledDays,
      commissionRestrictionOverride:
          commissionRestrictionOverride ?? this.commissionRestrictionOverride,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'businessName': name,
      'email': email,
      'materialType': materialType,
      'contact': contact,
      'phone': contact,
      'status': status,
      'rating': rating,
      'activeContracts': activeContracts,
      'contractValue': contractValue,
      'leadTimeDays': leadTimeDays,
      'city': city,
      'isVerified': isVerified,
      'categories': categories,
      if (paymentDetails != null) 'paymentDetails': paymentDetails,
      if (businessType != null) 'businessType': businessType,
      if (yearsInBusiness != null) 'yearsInBusiness': yearsInBusiness,
      if (businessRegistrationNumber != null)
        'businessRegistrationNumber': businessRegistrationNumber,
      if (ownerFullName != null) 'ownerFullName': ownerFullName,
      if (ownerFullName != null) 'ownerName': ownerFullName,
      if (cnicNumber != null) 'cnic': cnicNumber,
      if (cnicNumber != null) 'cnicNumber': cnicNumber,
      if (cnicFrontUrl != null) 'cnicFrontUrl': cnicFrontUrl,
      if (cnicBackUrl != null) 'cnicBackUrl': cnicBackUrl,
      if (businessAddress != null) 'businessAddress': businessAddress,
      if (deliveryCoverageAreas.isNotEmpty)
        'deliveryCoverageAreas': deliveryCoverageAreas,
      if (shopPhotoUrl != null) 'shopPhotoUrl': shopPhotoUrl,
      if (businessLicenseUrl != null) 'businessLicenseUrl': businessLicenseUrl,
      if (certificationUrl != null) 'certificationUrl': certificationUrl,
      if (declaredCategories.isNotEmpty)
        'declaredCategories': declaredCategories,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      'commissionRestricted': commissionRestricted,
      if (commissionRestrictionReason != null)
        'commissionRestrictionReason': commissionRestrictionReason,
      'commissionOutstandingAmount': commissionOutstandingAmount,
      'commissionOldestUnsettledDays': commissionOldestUnsettledDays,
      'commissionRestrictionOverride': commissionRestrictionOverride,
    };
  }

  factory SupplierModel.fromMap(Map<String, dynamic> map) {
    List<String> cats = [];
    if (map['categories'] is List) {
      cats = List<String>.from(map['categories']);
    }
    final declared = map['declaredCategories'] is List
        ? List<String>.from(map['declaredCategories'])
        : cats;

    int readInt(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? fallback;
    }

    double readDouble(dynamic value, {double fallback = 0}) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    return SupplierModel(
      id: (map['id'] ?? '') as String,
      name: (map['name'] ?? map['businessName'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      materialType: (map['materialType'] ??
              map['businessType'] ??
              (cats.isNotEmpty ? cats.first : ''))
          as String,
      contact: (map['contact'] ?? map['phone'] ?? '') as String,
      status: (map['status'] ?? 'Active') as String,
      rating: readDouble(map['rating']),
      activeContracts:
          readInt(map['activeContracts'] ?? map['totalCompanies']),
      contractValue: readDouble(map['contractValue']),
      leadTimeDays: readInt(map['leadTimeDays']),
      city: (map['city'] ?? '') as String,
      isVerified: (map['isVerified'] ?? false) as bool,
      categories: cats,
      paymentDetails: map['paymentDetails'] as String?,
      businessType: map['businessType'] as String?,
      yearsInBusiness: (map['yearsInBusiness'] as num?)?.toInt(),
      businessRegistrationNumber:
          map['businessRegistrationNumber'] as String?,
      ownerFullName:
          (map['ownerFullName'] ?? map['ownerName']) as String?,
      cnicNumber: (map['cnicNumber'] ?? map['cnic']) as String?,
      cnicFrontUrl: map['cnicFrontUrl'] as String?,
      cnicBackUrl: map['cnicBackUrl'] as String?,
      businessAddress: map['businessAddress'] as String?,
      deliveryCoverageAreas: map['deliveryCoverageAreas'] is List
          ? List<String>.from(map['deliveryCoverageAreas'])
          : const [],
      shopPhotoUrl: map['shopPhotoUrl'] as String?,
      businessLicenseUrl: map['businessLicenseUrl'] as String?,
      certificationUrl: map['certificationUrl'] as String?,
      declaredCategories: declared,
      rejectionReason: map['rejectionReason'] as String?,
      commissionRestricted: map['commissionRestricted'] == true,
      commissionRestrictionReason:
          map['commissionRestrictionReason'] as String?,
      commissionOutstandingAmount: readDouble(map['commissionOutstandingAmount']),
      commissionOldestUnsettledDays:
          readInt(map['commissionOldestUnsettledDays']),
      commissionRestrictionOverride:
          (map['commissionRestrictionOverride'] as String?) ?? 'none',
    );
  }
}
