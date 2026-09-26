import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/chat_message_model.dart';
import 'package:ratebridge/models/chat_thread_model.dart';
import 'package:ratebridge/viewmodels/chat_viewmodel.dart';

import '../mocks/mocks.dart';

ChatMessageModel _message({
  String id = 'msg-1',
  String chatId = 'chat-1',
  String content = 'Need 50 bags',
  String senderId = 'field-1',
  String senderName = 'Ali Raza',
  String receiverId = 'sup-1',
}) {
  return ChatMessageModel(
    id: id,
    chatId: chatId,
    companyId: 'co-1',
    senderId: senderId,
    senderName: senderName,
    receiverId: receiverId,
    content: content,
    timestamp: DateTime.utc(2026, 4, 1, 10),
  );
}

ChatThreadModel _thread({
  String chatId = 'chat-1',
  int unreadSupplier = 0,
  int unreadFieldUser = 0,
  String lastMessage = 'Need 50 bags',
}) {
  return ChatThreadModel(
    chatId: chatId,
    companyId: 'co-1',
    fieldUserId: 'field-1',
    supplierId: 'sup-1',
    supplierName: 'Cement House',
    fieldUserName: 'Ali Raza',
    lastMessage: lastMessage,
    lastMessageAt: DateTime.utc(2026, 4, 1, 10),
    lastSenderId: 'field-1',
    unreadFieldUser: unreadFieldUser,
    unreadSupplier: unreadSupplier,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fallbackMessage = _message();
  final fallbackThread = _thread();

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(fallbackMessage);
    registerFallbackValue(fallbackThread);
  });

  late MockChatRepository chatRepo;
  late StreamController<List<ChatThreadModel>> threadsStream;
  late StreamController<List<ChatMessageModel>> messagesStream;
  late ChatViewModel viewModel;

  setUp(() {
    chatRepo = MockChatRepository();
    threadsStream = StreamController<List<ChatThreadModel>>.broadcast();
    messagesStream = StreamController<List<ChatMessageModel>>.broadcast();

    when(() => chatRepo.watchSupplierThreads(any())).thenAnswer(
      (_) => threadsStream.stream,
    );
    when(() => chatRepo.watchThreadMessages(any())).thenAnswer(
      (_) => messagesStream.stream,
    );
    when(() => chatRepo.markMessagesRead(any(), any())).thenAnswer((_) async {});
    when(() => chatRepo.sendChatMessage(any())).thenAnswer((_) async {});

    viewModel = ChatViewModel(chatRepo);
  });

  tearDown(() async {
    viewModel.dispose();
    if (!threadsStream.isClosed) await threadsStream.close();
    if (!messagesStream.isClosed) await messagesStream.close();
  });

  group('ChatViewModel.watchSupplierThreads', () {
    test('sets loading then stores emitted threads and unread count', () async {
      var notifies = 0;
      var loadingOnFirst = false;
      String? errorOnFirst;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) {
          loadingOnFirst = viewModel.isLoading;
          errorOnFirst = viewModel.errorMessage;
        }
      });

      viewModel.watchSupplierThreads('sup-1');

      expect(loadingOnFirst, isTrue);
      expect(errorOnFirst, isNull);
      expect(viewModel.isLoading, isTrue);
      expect(viewModel.unreadMessageCount, 0);
      verify(() => chatRepo.watchSupplierThreads('sup-1')).called(1);

      final threads = [
        _thread(chatId: 'chat-1', unreadSupplier: 2),
        _thread(chatId: 'chat-2', unreadSupplier: 3, unreadFieldUser: 9),
      ];
      threadsStream.add(threads);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.threads, threads);
      expect(viewModel.unreadMessageCount, 5);
      expect(viewModel.errorMessage, isNull);
      expect(notifies, 2);
    });

    test('later emissions replace threads', () async {
      viewModel.watchSupplierThreads('sup-1');
      threadsStream.add([_thread(unreadSupplier: 1)]);
      await Future<void>.delayed(Duration.zero);

      threadsStream.add([
        _thread(chatId: 'chat-9', unreadSupplier: 4, lastMessage: 'Updated'),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.threads, hasLength(1));
      expect(viewModel.threads.single.chatId, 'chat-9');
      expect(viewModel.unreadMessageCount, 4);
      expect(viewModel.isLoading, isFalse);
    });

    test('empty snapshot clears threads and stops loading', () async {
      viewModel.watchSupplierThreads('sup-1');
      threadsStream.add([_thread(unreadSupplier: 2)]);
      await Future<void>.delayed(Duration.zero);

      threadsStream.add(const []);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.threads, isEmpty);
      expect(viewModel.unreadMessageCount, 0);
      expect(viewModel.isLoading, isFalse);
    });

    test('stream error sets errorMessage and clears loading', () async {
      viewModel.watchSupplierThreads('sup-1');

      threadsStream.addError(Exception('threads offline'));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, contains('threads offline'));
    });

    test('rewatch cancels the previous subscription', () async {
      final first = StreamController<List<ChatThreadModel>>.broadcast();
      final second = StreamController<List<ChatThreadModel>>.broadcast();
      addTearDown(() async {
        if (!first.isClosed) await first.close();
        if (!second.isClosed) await second.close();
      });

      when(() => chatRepo.watchSupplierThreads('sup-1'))
          .thenAnswer((_) => first.stream);
      when(() => chatRepo.watchSupplierThreads('sup-2'))
          .thenAnswer((_) => second.stream);

      viewModel.watchSupplierThreads('sup-1');
      viewModel.watchSupplierThreads('sup-2');

      first.add([_thread(chatId: 'old', unreadSupplier: 9)]);
      second.add([_thread(chatId: 'new', unreadSupplier: 1)]);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.threads, hasLength(1));
      expect(viewModel.threads.single.chatId, 'new');
      expect(viewModel.unreadMessageCount, 1);
    });
  });

  group('ChatViewModel.startListening', () {
    test('marks the thread read then stores streamed messages', () async {
      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoadingMessages;
      });

      await viewModel.startListening('chat-1', currentUserId: 'field-1');

      expect(loadingOnFirst, isTrue);
      expect(viewModel.messages, isEmpty);
      verify(() => chatRepo.markMessagesRead('chat-1', 'field-1')).called(1);
      verify(() => chatRepo.watchThreadMessages('chat-1')).called(1);

      final incoming = [_message(), _message(id: 'msg-2', content: 'On the way')];
      messagesStream.add(incoming);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.isLoadingMessages, isFalse);
      expect(viewModel.messages, incoming);
      expect(viewModel.errorMessage, isNull);
      expect(notifies, 2);
    });

    test('later emissions replace the message list', () async {
      await viewModel.startListening('chat-1', currentUserId: 'field-1');
      messagesStream.add([_message()]);
      await Future<void>.delayed(Duration.zero);

      messagesStream.add([_message(id: 'msg-9', content: 'Delivered')]);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.messages, hasLength(1));
      expect(viewModel.messages.single.content, 'Delivered');
      expect(viewModel.isLoadingMessages, isFalse);
    });

    test('does not resubscribe when the same thread is already active',
        () async {
      await viewModel.startListening('chat-1', currentUserId: 'field-1');
      messagesStream.add([_message()]);
      await Future<void>.delayed(Duration.zero);

      await viewModel.startListening('chat-1', currentUserId: 'field-1');

      verify(() => chatRepo.markMessagesRead('chat-1', 'field-1')).called(1);
      verify(() => chatRepo.watchThreadMessages('chat-1')).called(1);
      expect(viewModel.messages, hasLength(1));
    });

    test('switching threads cancels the previous subscription', () async {
      final first = StreamController<List<ChatMessageModel>>.broadcast();
      final second = StreamController<List<ChatMessageModel>>.broadcast();
      addTearDown(() async {
        if (!first.isClosed) await first.close();
        if (!second.isClosed) await second.close();
      });

      when(() => chatRepo.watchThreadMessages('chat-1'))
          .thenAnswer((_) => first.stream);
      when(() => chatRepo.watchThreadMessages('chat-2'))
          .thenAnswer((_) => second.stream);

      await viewModel.startListening('chat-1', currentUserId: 'field-1');
      first.add([_message(chatId: 'chat-1')]);
      await Future<void>.delayed(Duration.zero);

      await viewModel.startListening('chat-2', currentUserId: 'field-1');
      expect(viewModel.messages, isEmpty);
      expect(viewModel.isLoadingMessages, isTrue);

      first.add([_message(id: 'stale', chatId: 'chat-1')]);
      second.add([_message(id: 'fresh', chatId: 'chat-2', content: 'Hi')]);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.messages, hasLength(1));
      expect(viewModel.messages.single.id, 'fresh');
      expect(viewModel.isLoadingMessages, isFalse);
      verify(() => chatRepo.markMessagesRead('chat-2', 'field-1')).called(1);
    });

    test('message stream error sets errorMessage and clears loading', () async {
      await viewModel.startListening('chat-1', currentUserId: 'field-1');

      messagesStream.addError(Exception('messages offline'));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.isLoadingMessages, isFalse);
      expect(viewModel.errorMessage, contains('messages offline'));
    });

    test('markRead failure propagates and skips the message subscription',
        () async {
      when(() => chatRepo.markMessagesRead(any(), any()))
          .thenThrow(Exception('denied'));

      var notifies = 0;
      viewModel.addListener(() => notifies++);

      await expectLater(
        viewModel.startListening('chat-1', currentUserId: 'field-1'),
        throwsA(isA<Exception>()),
      );

      expect(notifies, 1);
      expect(viewModel.isLoadingMessages, isTrue);
      expect(viewModel.messages, isEmpty);
      verifyNever(() => chatRepo.watchThreadMessages(any()));
    });
  });

  group('ChatViewModel.openChatThread', () {
    test('delegates to startListening', () async {
      await viewModel.openChatThread('chat-1', 'field-1');

      verify(() => chatRepo.markMessagesRead('chat-1', 'field-1')).called(1);
      verify(() => chatRepo.watchThreadMessages('chat-1')).called(1);

      messagesStream.add([_message()]);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.messages.single.id, 'msg-1');
      expect(viewModel.isLoadingMessages, isFalse);
    });
  });

  group('ChatViewModel.sendMessage', () {
    test('empty text without an image returns false without sending', () async {
      var notifies = 0;
      viewModel.addListener(() => notifies++);

      final ok = await viewModel.sendMessage('chat-1', '   ');

      expect(ok, isFalse);
      expect(notifies, 0);
      expect(viewModel.isSending, isFalse);
      verifyNever(() => chatRepo.sendChatMessage(any()));
    });

    test('empty attachmentUrl is treated as no image', () async {
      final ok = await viewModel.sendMessage(
        'chat-1',
        '',
        'field-1',
        'Ali Raza',
        'sup-1',
        'co-1',
        '',
      );

      expect(ok, isFalse);
      verifyNever(() => chatRepo.sendChatMessage(any()));
    });

    test('success trims text, toggles sending, and forwards the message',
        () async {
      var notifies = 0;
      var sendingOnFirst = false;
      String? errorOnFirst;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) {
          sendingOnFirst = viewModel.isSending;
          errorOnFirst = viewModel.errorMessage;
        }
      });

      final ok = await viewModel.sendMessage(
        'chat-1',
        '  Need 50 bags  ',
        'field-1',
        'Ali Raza',
        'sup-1',
        'co-1',
      );

      expect(ok, isTrue);
      expect(sendingOnFirst, isTrue);
      expect(errorOnFirst, isNull);
      expect(viewModel.isSending, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(notifies, 2);

      final sent = verify(() => chatRepo.sendChatMessage(captureAny()))
          .captured
          .single as ChatMessageModel;
      expect(sent.id, isEmpty);
      expect(sent.chatId, 'chat-1');
      expect(sent.companyId, 'co-1');
      expect(sent.senderId, 'field-1');
      expect(sent.senderName, 'Ali Raza');
      expect(sent.receiverId, 'sup-1');
      expect(sent.content, 'Need 50 bags');
      expect(sent.attachmentUrl, isNull);
      expect(sent.isRead, isFalse);
    });

    test('image-only message is sent with empty content', () async {
      final ok = await viewModel.sendMessage(
        'chat-1',
        '   ',
        'field-1',
        'Ali Raza',
        'sup-1',
        'co-1',
        'https://cdn.example/site.jpg',
      );

      expect(ok, isTrue);
      final sent = verify(() => chatRepo.sendChatMessage(captureAny()))
          .captured
          .single as ChatMessageModel;
      expect(sent.content, isEmpty);
      expect(sent.attachmentUrl, 'https://cdn.example/site.jpg');
    });

    test('repository failure sets errorMessage and returns false', () async {
      when(() => chatRepo.sendChatMessage(any()))
          .thenThrow(Exception('write denied'));

      var notifies = 0;
      var sendingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) sendingOnFirst = viewModel.isSending;
      });

      final ok = await viewModel.sendMessage(
        'chat-1',
        'Hello',
        'field-1',
        'Ali Raza',
        'sup-1',
      );

      expect(ok, isFalse);
      expect(sendingOnFirst, isTrue);
      expect(viewModel.isSending, isFalse);
      expect(notifies, 2);
      expect(viewModel.errorMessage, contains('write denied'));
    });
  });

  group('ChatViewModel.markRead', () {
    test('forwards chatId and current user to the repository', () async {
      await viewModel.markRead('chat-1', 'field-1');

      verify(() => chatRepo.markMessagesRead('chat-1', 'field-1')).called(1);
    });

    test('repository failure propagates', () async {
      when(() => chatRepo.markMessagesRead(any(), any()))
          .thenThrow(Exception('denied'));

      await expectLater(
        viewModel.markRead('chat-1', 'field-1'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ChatViewModel.stopListening', () {
    test('clears messages and ignores later stream events', () async {
      await viewModel.startListening('chat-1', currentUserId: 'field-1');
      messagesStream.add([_message()]);
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.messages, isNotEmpty);

      var notifies = 0;
      viewModel.addListener(() => notifies++);

      viewModel.stopListening();

      expect(viewModel.messages, isEmpty);
      expect(notifies, 0);

      messagesStream.add([_message(id: 'after-stop')]);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.messages, isEmpty);
    });
  });

  group('ChatViewModel getters', () {
    test('isChatLocked is always false', () {
      expect(viewModel.isChatLocked, isFalse);
    });

    test('threadPreview delegates to ChatImageUtils', () {
      expect(
        ChatViewModel.threadPreview(text: '  Hello  '),
        'Hello',
      );
      expect(
        ChatViewModel.threadPreview(text: '   ', hasImage: true),
        'Photo',
      );
      expect(
        ChatViewModel.threadPreview(text: '   ', hasImage: false),
        isEmpty,
      );
    });
  });
}
