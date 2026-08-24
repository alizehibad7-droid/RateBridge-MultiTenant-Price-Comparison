// MVVM: Repository — Firestore access only
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';
import '../utils/app_exception.dart';

class NotificationRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  NotificationRepository(FirestoreService _);

  /// Watches notifications for a specific user.
  /// [path] allows scoping to company or supplier sub-collections.
  Stream<List<NotificationModel>> watchNotifications(String uid, {String? path}) {
    try {
      final collection = _db.collection(path ?? 'notifications');
      return collection
          .where('userId', isEqualTo: uid)
          .snapshots()
          .map((snapshot) {
        final notifications = snapshot.docs
            .map((doc) => NotificationModel.fromMap(
                  doc.id,
                  doc.data(),
                ))
            .toList();
        notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (notifications.length > 50) {
          return notifications.sublist(0, 50);
        }
        return notifications;
      }).handleError((Object error, StackTrace stackTrace) {
        if (error is FirebaseException &&
            error.code == 'failed-precondition') {
          throw AppException(
            'Notifications index is building. Please wait 2 minutes and retry.',
          );
        }
        throw error;
      });
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        throw AppException(
          'Notifications index is building. Please wait 2 minutes and retry.',
        );
      }
      throw AppException('Failed to watch notifications: ${e.message}');
    }
  }

  Stream<int> watchUnreadCount(String uid, {String? path}) {
    try {
      final collection = _db.collection(path ?? 'notifications');
      return collection
          .where('userId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.length)
          .handleError((Object error, StackTrace stackTrace) {
        if (error is FirebaseException &&
            error.code == 'failed-precondition') {
          throw AppException(
            'Notifications index is building. Please wait 2 minutes and retry.',
          );
        }
        throw error;
      });
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        throw AppException(
          'Notifications index is building. Please wait 2 minutes and retry.',
        );
      }
      throw AppException('Failed to watch unread count: ${e.message}');
    }
  }

  Future<void> createNotification(NotificationModel notification, {String? path}) async {
    try {
      final collection = _db.collection(path ?? 'notifications');
      await collection
          .doc(notification.notifId)
          .set(notification.toMap());
    } on FirebaseException catch (e) {
      throw AppException('Failed to create notification: ${e.message}');
    }
  }

  Future<void> markAsRead(String uid, String notifId, {String? path}) async {
    try {
      final collection = _db.collection(path ?? 'notifications');
      await collection.doc(notifId).update({'isRead': true});
    } on FirebaseException catch (e) {
      throw AppException('Failed to mark notification as read: ${e.message}');
    }
  }

  Future<void> markAllRead(String uid, {String? path}) async {
    try {
      final collection = _db.collection(path ?? 'notifications');
      final batch = _db.batch();
      final unread = await collection
          .where('userId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw AppException('Failed to mark all notifications as read: ${e.message}');
    }
  }
}
