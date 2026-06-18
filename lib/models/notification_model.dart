// MVVM: Model — pure Dart
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notifId;
  final String userId;
  final String type; // orderUpdate|approval|delivery|commission|chat|invitation|payment
  final String title;
  final String body;
  final Map<String, dynamic> data; // orderId, companyId, etc.
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.notifId,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) => NotificationModel(
    notifId: id,
    userId: map['userId'] ?? '',
    type: map['type'] ?? '',
    title: map['title'] ?? '',
    body: map['body'] ?? '',
    data: Map<String, dynamic>.from(map['data'] ?? {}),
    isRead: map['isRead'] ?? false,
    createdAt: map['createdAt'] is Timestamp 
        ? (map['createdAt'] as Timestamp).toDate() 
        : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'type': type,
    'title': title,
    'body': body,
    'data': data,
    'isRead': isRead,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
