// MVVM: Model — pure Dart
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notifId;
  final String recipientUserId;
  final String recipientRole;
  final String type; // order|partnership|payment|system|chat
  final String title;
  final String message;
  final Map<String, dynamic> data; // orderId, companyId, relatedId, relatedCollection
  final bool isRead;
  final DateTime createdAt;
  final String? senderUserId;
  final String? companyId;

  NotificationModel({
    required this.notifId,
    required this.recipientUserId,
    required this.recipientRole,
    required this.type,
    required this.title,
    required this.message,
    required this.data,
    required this.isRead,
    required this.createdAt,
    this.senderUserId,
    this.companyId,
  });

  // Getter for backward compatibility with UI code using .body
  String get body => message;

  factory NotificationModel.fromMap(String id, Map<String, dynamic> map) => NotificationModel(
    notifId: id,
    recipientUserId: map['recipientUserId'] ?? map['userId'] ?? '',
    recipientRole: map['recipientRole'] ?? '',
    type: map['type'] ?? '',
    title: map['title'] ?? '',
    message: map['message'] ?? map['body'] ?? '',
    data: Map<String, dynamic>.from(map['data'] ?? {}),
    isRead: map['isRead'] ?? map['read'] ?? false,
    createdAt: map['createdAt'] is Timestamp 
        ? (map['createdAt'] as Timestamp).toDate() 
        : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
    senderUserId: map['senderUserId'],
    companyId: map['companyId'],
  );

  Map<String, dynamic> toMap() => {
    'notificationId': notifId,
    'recipientUserId': recipientUserId,
    'recipientRole': recipientRole,
    'type': type,
    'title': title,
    'message': message,
    'data': data,
    'isRead': isRead,
    'createdAt': createdAt, // Usually FieldValue.serverTimestamp() when sending to Firestore
    'senderUserId': senderUserId,
    'companyId': companyId,
  };
}
