// MVVM: Repository — Firestore access only
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';
import '../utils/app_exception.dart';

class NotificationRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  NotificationRepository(FirestoreService _);

  // REQUIRED FIRESTORE COMPOSITE INDEX (create if queries fail with
  // failed-precondition):
  //   Firebase Console → Firestore → Indexes → Composite → Add Index
  //   Collection: notifications
  //   Field 1: userId (Ascending)
  //   Field 2: isRead (Ascending)
  //   Query scope: Collection
  // Or open the auto-generated link from the Flutter debug console:
  //   https://console.firebase.google.com/.../firestore/indexes?create_composite=...
  // Click "Create Index" and wait 2–3 minutes for it to build.
  //
  // If you see permission-denied, deploy firestore.rules with explicit
  // get/list/create/update rules on /notifications/{notifId}.
  Stream<List<NotificationModel>> watchNotifications(String uid) {
    try {
      return _db
          .collection('notifications')
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

  // Same composite index as watchNotifications (userId + isRead) for unread count.
  Stream<int> watchUnreadCount(String uid) {
    try {
      return _db
          .collection('notifications')
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

  Future<void> createNotification(NotificationModel notification) async {
    try {
      await _db
          .collection('notifications')
          .doc(notification.notifId)
          .set(notification.toMap());
    } on FirebaseException catch (e) {
      throw AppException('Failed to create notification: ${e.message}');
    }
  }

  Future<void> markAsRead(String uid, String notifId) async {
    try {
      await _db.collection('notifications').doc(notifId).update({'isRead': true});
    } on FirebaseException catch (e) {
      throw AppException('Failed to mark notification as read: ${e.message}');
    }
  }

  Future<void> markAllRead(String uid) async {
    try {
      final batch = _db.batch();
      final unread = await _db
          .collection('notifications')
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
