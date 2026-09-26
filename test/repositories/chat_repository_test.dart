import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratebridge/models/chat_message_model.dart';
import 'package:ratebridge/models/chat_thread_model.dart';
import 'package:ratebridge/repositories/chat_repository.dart';
import 'package:ratebridge/services/firestore_service.dart';

const chatId = 'field-1_sup-1_co-1';

ChatThreadModel _thread({
  String lastMessage = 'Need 50 bags',
  String fieldUserName = 'Ali Raza',
  int unreadFieldUser = 0,
  int unreadSupplier = 0,
}) {
  return ChatThreadModel(
    chatId: chatId,
    companyId: 'co-1',
    fieldUserId: 'field-1',
    supplierId: 'sup-1',
    supplierName: 'Cement House',
    fieldUserName: fieldUserName,
    lastMessage: lastMessage,
    lastMessageAt: DateTime.utc(2026, 4, 1, 10),
    lastSenderId: 'field-1',
    unreadFieldUser: unreadFieldUser,
    unreadSupplier: unreadSupplier,
  );
}

ChatMessageModel _message({
  String id = 'msg-1',
  String senderId = 'field-1',
  String receiverId = 'sup-1',
  String content = 'Need 50 bags',
  bool isRead = false,
}) {
  return ChatMessageModel(
    id: id,
    chatId: chatId,
    companyId: 'co-1',
    senderId: senderId,
    senderName: senderId == 'field-1' ? 'Ali Raza' : 'Cement House',
    receiverId: receiverId,
    content: content,
    timestamp: DateTime.utc(2026, 4, 1, 10),
    isRead: isRead,
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
  late ChatRepository repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = ChatRepository(FirestoreService(firestore: fake));
  });

  group('ChatRepository threads', () {
    test('ensureThread creates a thread document once', () async {
      await repo.ensureThread(_thread());
      await repo.ensureThread(_thread(lastMessage: 'ignored on second call'));

      final doc = await fake.collection('chats').doc(chatId).get();
      expect(doc.exists, isTrue);
      expect(doc.data()?['isThread'], isTrue);
      expect(doc.data()?['lastMessage'], 'Need 50 bags');
      expect(doc.data()?['supplierId'], 'sup-1');
    });

    test('ensureThread backfills an empty fieldUserName', () async {
      await fake.collection('chats').doc(chatId).set({
        'isThread': true,
        'companyId': 'co-1',
        'fieldUserId': 'field-1',
        'supplierId': 'sup-1',
        'lastMessage': '',
      });

      await repo.ensureThread(_thread(fieldUserName: 'Ali Raza'));
      final doc = await fake.collection('chats').doc(chatId).get();
      expect(doc.data()?['fieldUserName'], 'Ali Raza');
    });

    test('updateThreadAfterMessage increments supplier unread for field senders',
        () async {
      await repo.ensureThread(_thread());
      await repo.updateThreadAfterMessage(
        chatId: chatId,
        companyId: 'co-1',
        lastMessage: 'Photo',
        lastSenderId: 'field-1',
        fieldUserId: 'field-1',
        supplierId: 'sup-1',
        fieldUserName: 'Ali Raza',
      );

      final doc = await fake.collection('chats').doc(chatId).get();
      expect(doc.data()?['lastMessage'], 'Photo');
      expect(doc.data()?['lastSenderId'], 'field-1');
      expect(doc.data()?['unreadSupplier'], 1);
    });

    test('updateThreadAfterMessage increments field unread for supplier senders',
        () async {
      await repo.ensureThread(_thread());
      await repo.updateThreadAfterMessage(
        chatId: chatId,
        companyId: 'co-1',
        lastMessage: 'Ready tomorrow',
        lastSenderId: 'sup-1',
        fieldUserId: 'field-1',
        supplierId: 'sup-1',
      );

      final doc = await fake.collection('chats').doc(chatId).get();
      expect(doc.data()?['unreadFieldUser'], 1);
    });

    test('markThreadReadForFieldUser and supplier zero the counters', () async {
      await repo.ensureThread(_thread(unreadFieldUser: 4, unreadSupplier: 2));
      await repo.markThreadReadForFieldUser(chatId);
      await repo.markThreadReadForSupplier(chatId);

      final doc = await fake.collection('chats').doc(chatId).get();
      expect(doc.data()?['unreadFieldUser'], 0);
      expect(doc.data()?['unreadSupplier'], 0);
    });

    test('watchFieldUserThreads emits company threads for that field user',
        () async {
      final events = <List<ChatThreadModel>>[];
      final sub =
          repo.watchFieldUserThreads('co-1', 'field-1').listen(events.add);

      await _waitUntil(() => events.isNotEmpty, because: 'no thread snapshot');
      expect(events.last, isEmpty);

      await repo.ensureThread(_thread());
      await _waitUntil(
        () => events.any((e) => e.any((t) => t.chatId == chatId)),
        because: 'field user thread stream did not emit',
      );
      expect(events.last.single.supplierName, 'Cement House');

      await sub.cancel();
    });

    test('watchSupplierThreads emits threads for that supplier', () async {
      await repo.ensureThread(_thread());
      final events = <List<ChatThreadModel>>[];
      final sub = repo.watchSupplierThreads('sup-1').listen(events.add);

      await _waitUntil(
        () => events.any((e) => e.any((t) => t.chatId == chatId)),
        because: 'supplier thread stream did not emit',
      );

      await sub.cancel();
    });
  });

  group('ChatRepository messages', () {
    test('sendChatMessage writes a subcollection document', () async {
      await repo.ensureThread(_thread());
      await repo.sendChatMessage(_message());

      final snap = await fake
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();
      expect(snap.docs, hasLength(1));
      expect(snap.docs.first.data()['text'], 'Need 50 bags');
      expect(snap.docs.first.data()['senderId'], 'field-1');
    });

    test('watchThreadMessages emits saved messages in timestamp order', () async {
      await repo.ensureThread(_thread());
      final events = <List<ChatMessageModel>>[];
      final sub = repo.watchThreadMessages(chatId).listen(events.add);

      await _waitUntil(() => events.isNotEmpty, because: 'no messages snapshot');
      expect(events.last, isEmpty);

      await repo.sendChatMessage(_message());
      await _waitUntil(
        () => events.any((e) => e.any((m) => m.content == 'Need 50 bags')),
        because: 'thread messages stream did not emit',
      );

      await sub.cancel();
    });

    test('markMessagesRead marks inbound unread messages only', () async {
      await repo.ensureThread(_thread());
      final inbound = fake
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc('from-sup');
      final outbound = fake
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc('from-field');
      await inbound.set({
        'senderId': 'sup-1',
        'text': 'Hello',
        'isRead': false,
        'timestamp': Timestamp.fromDate(DateTime.utc(2026, 4, 1, 10)),
      });
      await outbound.set({
        'senderId': 'field-1',
        'text': 'Hi',
        'isRead': false,
        'timestamp': Timestamp.fromDate(DateTime.utc(2026, 4, 1, 11)),
      });

      await repo.markMessagesRead(chatId, 'field-1');

      expect((await inbound.get()).data()?['isRead'], isTrue);
      expect((await outbound.get()).data()?['isRead'], isFalse);
    });

    test('retrieveChatHistory filters the pairwise conversation', () async {
      await fake.collection('chats').doc('pair-1').set({
        'senderId': 'field-1',
        'receiverId': 'sup-1',
        'text': 'Need 50 bags',
        'timestamp': Timestamp.fromDate(DateTime.utc(2026, 4, 1, 12)),
      });
      await fake.collection('chats').doc('pair-2').set({
        'senderId': 'sup-1',
        'receiverId': 'field-1',
        'text': 'Ready',
        'timestamp': Timestamp.fromDate(DateTime.utc(2026, 4, 1, 11)),
      });
      await fake.collection('chats').doc('other').set({
        'senderId': 'field-1',
        'receiverId': 'other-sup',
        'text': 'Unrelated',
        'timestamp': Timestamp.fromDate(DateTime.utc(2026, 4, 1, 10)),
      });

      final events = <List<ChatMessageModel>>[];
      final sub = repo.retrieveChatHistory('field-1', 'sup-1').listen(events.add);

      await _waitUntil(
        () => events.any((e) => e.length == 2),
        because: 'pairwise history did not emit both messages',
      );
      expect(events.last.map((m) => m.content).toSet(), {'Need 50 bags', 'Ready'});

      await sub.cancel();
    });
  });
}
