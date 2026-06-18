// MVVM: Model — pure Dart
import 'package:cloud_firestore/cloud_firestore.dart';

class RatingModel {
  final String id;
  final String orderId;
  final String supplierUid;
  final String userId;
  final String userName;
  final String materialId;
  final String materialName; // Added for filtering and display
  final double rating;
  final String comment;
  final Map<String, double> dimensions;
  final DateTime createdAt;

  RatingModel({
    required this.id,
    required this.orderId,
    required this.supplierUid,
    required this.userId,
    required this.userName,
    required this.materialId,
    required this.materialName,
    required this.rating,
    required this.comment,
    this.dimensions = const {},
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'orderId': orderId,
    'supplierUid': supplierUid,
    'userId': userId,
    'userName': userName,
    'materialId': materialId,
    'materialName': materialName,
    'rating': rating,
    'comment': comment,
    'dimensions': dimensions,
    'createdAt': FieldValue.serverTimestamp(),
  };

  factory RatingModel.fromMap(String id, Map<String, dynamic> map) => RatingModel(
    id: id,
    orderId: map['orderId'] ?? '',
    supplierUid: map['supplierUid'] ?? '',
    userId: map['userId'] ?? '',
    userName: map['userName'] ?? '',
    materialId: map['materialId'] ?? '',
    materialName: map['materialName'] ?? '',
    rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
    comment: map['comment'] ?? '',
    dimensions: Map<String, double>.from(
      (map['dimensions'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))
    ),
    createdAt: map['createdAt'] is Timestamp 
        ? (map['createdAt'] as Timestamp).toDate() 
        : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );

  // Getters for dimensions to support UI score display
  double get qualityScore => dimensions['Quality'] ?? 0.0;
  double get packagingScore => dimensions['Packaging'] ?? 0.0;
  double get quantityScore => dimensions['Quantity'] ?? 0.0;
  double get timelinessScore => dimensions['Timeliness'] ?? 0.0;
}
