import 'package:cloud_firestore/cloud_firestore.dart';

enum DisputeType {
  wrongMaterial,
  damagedGoods,
  quantityMismatch,
  nonDelivery,
  paymentIssue,
  other,
}

extension DisputeTypeExtension on DisputeType {
  String get label {
    switch (this) {
      case DisputeType.wrongMaterial:
        return 'Wrong Material';
      case DisputeType.damagedGoods:
        return 'Damaged Goods';
      case DisputeType.quantityMismatch:
        return 'Quantity Mismatch';
      case DisputeType.nonDelivery:
        return 'Non-Delivery';
      case DisputeType.paymentIssue:
        return 'Payment Issue';
      case DisputeType.other:
        return 'Other';
    }
  }
}

class DisputeModel {
  final String id;
  final String orderId;
  final String supplierId;
  final String companyId;
  final String raisedByUid;
  final String raisedByRole;
  final String? raisedByName;
  final DisputeType type;
  final String description;
  final String? photoUrl;
  final String status; // 'open' | 'under_review' | 'resolved'
  final String? resolutionNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  DisputeModel({
    required this.id,
    required this.orderId,
    required this.supplierId,
    required this.companyId,
    required this.raisedByUid,
    required this.raisedByRole,
    this.raisedByName,
    required this.type,
    required this.description,
    this.photoUrl,
    required this.status,
    this.resolutionNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DisputeModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    final photoUrl = map['photoUrl']?.toString().trim();
    final notes = map['resolutionNotes']?.toString().trim();
    return DisputeModel(
      id: id,
      orderId: map['orderId'] ?? '',
      supplierId: map['supplierId'] ?? '',
      companyId: map['companyId'] ?? '',
      raisedByUid: map['raisedByUid'] ?? '',
      raisedByRole: map['raisedByRole'] ?? '',
      raisedByName: map['raisedByName']?.toString(),
      type: DisputeType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => DisputeType.other,
      ),
      description: map['description'] ?? '',
      photoUrl: (photoUrl == null || photoUrl.isEmpty) ? null : photoUrl,
      status: map['status'] ?? 'open',
      resolutionNotes: (notes == null || notes.isEmpty) ? null : notes,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt'] ?? map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'supplierId': supplierId,
      'companyId': companyId,
      'raisedByUid': raisedByUid,
      'raisedByRole': raisedByRole,
      'raisedByName': raisedByName,
      'type': type.name,
      'description': description,
      'photoUrl': photoUrl,
      'status': status,
      'resolutionNotes': resolutionNotes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
