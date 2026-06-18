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
    };
  }

  factory SupplierModel.fromMap(Map<String, dynamic> map) {
    List<String> cats = [];
    if (map['categories'] is List) {
      cats = List<String>.from(map['categories']);
    }

    return SupplierModel(
      id: (map['id'] ?? '') as String,
      name: (map['name'] ?? map['businessName'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      materialType: (map['materialType'] ?? map['businessType'] ?? (cats.isNotEmpty ? cats.first : '')) as String,
      contact: (map['contact'] ?? map['phone'] ?? '') as String,
      status: (map['status'] ?? 'Active') as String,
      rating: (map['rating'] as num? ?? 0.0).toDouble(),
      activeContracts: (map['activeContracts'] ?? map['totalCompanies'] ?? 0) as int,
      contractValue: (map['contractValue'] as num? ?? 0.0).toDouble(),
      leadTimeDays: (map['leadTimeDays'] ?? 0) as int,
      city: (map['city'] ?? '') as String,
      isVerified: (map['isVerified'] ?? false) as bool,
      categories: cats,
    );
  }
}
