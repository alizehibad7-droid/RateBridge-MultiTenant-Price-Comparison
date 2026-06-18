// MVVM: Repository — Firestore access only
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';
import '../constants/firestore_paths.dart';
import '../utils/app_exception.dart';

class NotificationRepository {
  final FirestoreService _firestoreService;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  NotificationRepository(this._firestoreService);

  Stream<List<NotificationModel>> watchNotifications(String uid) {
    try {
      return _db
          .collection(FirestorePaths.userNotificationsCol(uid))
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map((s) => s.docs.map((d) =>
            NotificationModel.fromMap(d.id, d.data() as Map<String, dynamic>)).toList());
    } on FirebaseException catch (e) {
      throw AppException('Failed to watch notifications: ${e.message}');
    }
  }

  Stream<int> watchUnreadCount(String uid) {
    try {
      return _db
          .collection(FirestorePaths.userNotificationsCol(uid))
          .where('isRead', isEqualTo: false)
          .snapshots()
          .map((s) => s.docs.length);
    } on FirebaseException catch (e) {
      throw AppException('Failed to watch unread count: ${e.message}');
    }
  }

  Future<void> markAsRead(String uid, String notifId) async {
    try {
      await _db
          .collection(FirestorePaths.userNotificationsCol(uid))
          .doc(notifId)
          .update({'isRead': true});
    } on FirebaseException catch (e) {
      throw AppException('Failed to mark notification as read: ${e.message}');
    }
  }

  Future<void> markAllRead(String uid) async {
    try {
      final batch = _db.batch();
      final unread = await _db
          .collection(FirestorePaths.userNotificationsCol(uid))
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
