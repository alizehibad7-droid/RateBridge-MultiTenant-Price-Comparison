// MVVM: Repository — Firestore access only
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';
import '../utils/app_exception.dart';

class NotificationRepository {
  final FirebaseFirestore _db;

  NotificationRepository([
    FirestoreService? _,
    FirebaseFirestore? firestore,
  ]) : _db = firestore ?? FirebaseFirestore.instance;


  /// Watches notifications for a specific user in the root 'notifications' collection.
  Stream<List<NotificationModel>> watchNotifications(String uid) {
    return _db
        .collection('notifications')
        .where('recipientUserId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final notifications = snapshot.docs
          .map((doc) => NotificationModel.fromMap(
                doc.id,
                doc.data(),
              ))
          .toList();
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return notifications;
    }).handleError((Object error) {
      if (error is FirebaseException &&
          error.code == 'failed-precondition') {
        throw AppException(
          'Notifications index is building. Please wait 2 minutes and retry.',
        );
      }
      throw error;
    });
  }

  Stream<int> watchUnreadCount(String uid) {
    return _db
        .collection('notifications')
        .where('recipientUserId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((Object error) {
      if (error is FirebaseException &&
          error.code == 'failed-precondition') {
        // This query (uid + isRead) specifically requires a composite index.
        throw AppException(
          'Unread count index is missing. Please create a composite index for recipientUserId and isRead in Firestore.',
        );
      }
      throw error;
    });
  }

  Future<void> createNotification(NotificationModel notification) async {
    try {
      final ref = notification.notifId.isEmpty
          ? _db.collection('notifications').doc()
          : _db.collection('notifications').doc(notification.notifId);
      // create-only for deterministic ids so client/server races don't rewrite.
      final existing = await ref.get();
      if (existing.exists) return;
      await ref.set({
        ...notification.toMap(),
        'notifId': ref.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AppException('Failed to create notification: ${e.message}');
    }
  }

  Future<void> markAsRead(String notifId) async {
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
          .where('recipientUserId', isEqualTo: uid)
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

  Future<void> deleteNotification(String notifId) async {
    try {
      await _db.collection('notifications').doc(notifId).delete();
    } on FirebaseException catch (e) {
      throw AppException('Failed to delete notification: ${e.message}');
    }
  }

  Future<void> deleteNotifications(List<String> notifIds) async {
    try {
      final batch = _db.batch();
      for (final id in notifIds) {
        batch.delete(_db.collection('notifications').doc(id));
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw AppException('Failed to delete notifications: ${e.message}');
    }
  }

  Future<void> deleteAllNotifications(String uid) async {
    try {
      final snapshots = await _db
          .collection('notifications')
          .where('recipientUserId', isEqualTo: uid)
          .get();

      final batch = _db.batch();
      for (final doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw AppException('Failed to clear notifications: ${e.message}');
    }
  }

  /// Deletes notifications for [recipientUserId] whose data.relatedId / requestId
  /// matches [relatedId]. Optionally filter by [event] (e.g. invitation_received).
  Future<void> deleteByRelatedId({
    required String recipientUserId,
    required String relatedId,
    String? event,
  }) async {
    if (recipientUserId.isEmpty || relatedId.isEmpty) return;
    try {
      final snap = await _db
          .collection('notifications')
          .where('recipientUserId', isEqualTo: recipientUserId)
          .get();
      final batch = _db.batch();
      var count = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        final payload = Map<String, dynamic>.from(data['data'] as Map? ?? {});
        final rid = (payload['relatedId'] ?? payload['requestId'] ?? '')
            .toString();
        if (rid != relatedId) continue;
        if (event != null &&
            event.isNotEmpty &&
            (payload['event'] ?? '').toString() != event) {
          continue;
        }
        batch.delete(doc.reference);
        count++;
      }
      if (count > 0) await batch.commit();
    } on FirebaseException catch (e) {
      throw AppException(
        'Failed to clear related notifications: ${e.message}',
      );
    }
  }
}
