import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratebridge/models/notification_model.dart';
import 'package:ratebridge/repositories/notification_repository.dart';
import 'package:ratebridge/services/firestore_service.dart';

NotificationModel _notif({
  String id = 'notif-1',
  String recipient = 'field-1',
  bool isRead = false,
  DateTime? createdAt,
  String title = 'Order update',
}) {
  return NotificationModel(
    notifId: id,
    recipientUserId: recipient,
    recipientRole: 'field_user',
    type: 'order',
    title: title,
    message: 'Your order was accepted',
    data: const {'orderId': 'order-1'},
    isRead: isRead,
    createdAt: createdAt ?? DateTime.utc(2026, 4, 1, 10),
    companyId: 'co-1',
  );
}

Future<void> _waitUntil(
  bool Function() test, {
  String because = 'condition never became true',
}) async {
  for (var i = 0; i < 50; i++) {
    if (test()) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail(because);
}

void main() {
  late FakeFirebaseFirestore fake;
  late NotificationRepository repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = NotificationRepository(
      FirestoreService(firestore: fake),
      fake,
    );
  });

  group('NotificationRepository CRUD', () {
    test('createNotification writes a document with the given id', () async {
      await repo.createNotification(_notif());

      final doc = await fake.collection('notifications').doc('notif-1').get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['recipientUserId'], 'field-1');
      expect(doc.data()?['title'], 'Order update');
      expect(doc.data()?['isRead'], isFalse);
      expect(doc.data()?['createdAt'], isA<Timestamp>());
    });

    test('createNotification auto-ids an empty notifId', () async {
      await repo.createNotification(_notif(id: ''));

      final snap = await fake.collection('notifications').get();
      expect(snap.docs, hasLength(1));
      expect(snap.docs.first.id, isNotEmpty);
      expect(snap.docs.first.data()['recipientUserId'], 'field-1');
    });

    test('markAsRead sets isRead on that document', () async {
      await repo.createNotification(_notif());
      await repo.markAsRead('notif-1');

      final doc = await fake.collection('notifications').doc('notif-1').get();
      expect(doc.data()?['isRead'], isTrue);
    });

    test('markAllRead updates every unread row for that recipient', () async {
      await repo.createNotification(_notif(id: 'n-1'));
      await repo.createNotification(_notif(id: 'n-2', title: 'Second'));
      await repo.createNotification(
        _notif(id: 'n-other', recipient: 'field-2'),
      );
      await fake.collection('notifications').doc('n-read').set({
        'recipientUserId': 'field-1',
        'isRead': true,
        'title': 'Already read',
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 4, 1)),
      });

      await repo.markAllRead('field-1');

      expect(
        (await fake.collection('notifications').doc('n-1').get())
            .data()?['isRead'],
        isTrue,
      );
      expect(
        (await fake.collection('notifications').doc('n-2').get())
            .data()?['isRead'],
        isTrue,
      );
      expect(
        (await fake.collection('notifications').doc('n-other').get())
            .data()?['isRead'],
        isFalse,
      );
    });
  });

  group('NotificationRepository streams', () {
    test('watchNotifications emits newest first for that recipient', () async {
      await fake.collection('notifications').doc('older').set({
        ..._notif(id: 'older', title: 'Older').toMap(),
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 3, 1)),
      });
      await fake.collection('notifications').doc('newer').set({
        ..._notif(id: 'newer', title: 'Newer').toMap(),
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 4, 1)),
      });
      await fake.collection('notifications').doc('other').set({
        ..._notif(id: 'other', recipient: 'field-2').toMap(),
        'createdAt': Timestamp.fromDate(DateTime.utc(2026, 4, 2)),
      });

      final events = <List<NotificationModel>>[];
      final sub = repo.watchNotifications('field-1').listen(events.add);

      await _waitUntil(
        () => events.any((e) => e.length == 2),
        because: 'notification stream did not emit both rows',
      );
      expect(events.last.map((n) => n.notifId).toList(), ['newer', 'older']);

      await sub.cancel();
    });

    test('watchUnreadCount tracks unread rows for that recipient', () async {
      final counts = <int>[];
      final sub = repo.watchUnreadCount('field-1').listen(counts.add);

      await _waitUntil(() => counts.isNotEmpty, because: 'no unread snapshot');
      expect(counts.last, 0);

      await repo.createNotification(_notif(id: 'n-1'));
      await repo.createNotification(_notif(id: 'n-2'));
      await _waitUntil(
        () => counts.any((c) => c == 2),
        because: 'unread count did not become 2',
      );

      await repo.markAsRead('n-1');
      await _waitUntil(
        () => counts.any((c) => c == 1),
        because: 'unread count did not drop after markAsRead',
      );

      await sub.cancel();
    });
  });
}
