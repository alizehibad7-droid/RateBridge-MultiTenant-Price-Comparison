import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ratebridge/models/chat_message_model.dart';
import 'package:ratebridge/models/chat_thread_model.dart';
import 'package:ratebridge/utils/app_exception.dart';
import 'package:ratebridge/utils/chat_id_utils.dart';
import 'package:ratebridge/viewmodels/field_user/field_chat_viewmodel.dart';

import '../../mocks/mocks.dart';

ChatMessageModel _message({
  String id = 'msg-1',
  String chatId = 'field-1_sup-1_co-1',
  String content = 'Need 50 bags',
}) {
  return ChatMessageModel(
    id: id,
    chatId: chatId,
    companyId: 'co-1',
    senderId: 'field-1',
    senderName: 'Ali Raza',
    receiverId: 'sup-1',
    content: content,
    timestamp: DateTime.utc(2026, 4, 1, 10),
  );
}

ChatThreadModel _thread({
  String chatId = 'field-1_sup-1_co-1',
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
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fallbackMessage = _message();
  final fallbackThread = _thread();
  const chatId = 'field-1_sup-1_co-1';

  setUpAll(() {
    registerFallbackValue('');
    registerFallbackValue(fallbackMessage);
    registerFallbackValue(fallbackThread);
  });

  late MockChatRepository chatRepo;
  late MockNotificationService notifications;
  late StreamController<List<ChatThreadModel>> threadsStream;
  late StreamController<List<ChatMessageModel>> messagesStream;
  late FieldChatViewModel viewModel;

  setUp(() {
    chatRepo = MockChatRepository();
    notifications = MockNotificationService();
    threadsStream = StreamController<List<ChatThreadModel>>.broadcast();
    messagesStream = StreamController<List<ChatMessageModel>>.broadcast();

    when(() => chatRepo.watchFieldUserThreads(any(), any()))
        .thenAnswer((_) => threadsStream.stream);
    when(() => chatRepo.watchThreadMessages(any()))
        .thenAnswer((_) => messagesStream.stream);
    when(() => chatRepo.markMessagesRead(any(), any())).thenAnswer((_) async {});
    when(() => chatRepo.markThreadReadForFieldUser(any()))
        .thenAnswer((_) async {});
    when(() => chatRepo.ensureThread(any())).thenAnswer((_) async {});
    when(() => chatRepo.sendChatMessage(any())).thenAnswer((_) async {});
    when(
      () => chatRepo.updateThreadAfterMessage(
        chatId: any(named: 'chatId'),
        companyId: any(named: 'companyId'),
        lastMessage: any(named: 'lastMessage'),
        lastSenderId: any(named: 'lastSenderId'),
        fieldUserId: any(named: 'fieldUserId'),
        supplierId: any(named: 'supplierId'),
        fieldUserName: any(named: 'fieldUserName'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => notifications.notifyChatMessage(
        recipientUserId: any(named: 'recipientUserId'),
        senderName: any(named: 'senderName'),
        preview: any(named: 'preview'),
        chatId: any(named: 'chatId'),
        companyId: any(named: 'companyId'),
        fieldUserId: any(named: 'fieldUserId'),
        fieldUserName: any(named: 'fieldUserName'),
        supplierId: any(named: 'supplierId'),
        supplierName: any(named: 'supplierName'),
      ),
    ).thenAnswer((_) async {});

    viewModel = FieldChatViewModel(chatRepo, notifications);
  });

  tearDown(() async {
    viewModel.dispose();
    if (!threadsStream.isClosed) await threadsStream.close();
    if (!messagesStream.isClosed) await messagesStream.close();
  });

  Future<bool> sendDefault({
    String content = 'Need 50 bags',
    String? attachmentUrl,
  }) {
    return viewModel.sendMessage(
      companyId: 'co-1',
      fieldUserId: 'field-1',
      fieldUserName: 'Ali Raza',
      supplierId: 'sup-1',
      supplierName: 'Cement House',
      content: content,
      attachmentUrl: attachmentUrl,
    );
  }

  group('FieldChatViewModel.chatIdFor', () {
    test('matches ChatIdUtils participant sorting', () {
      expect(
        FieldChatViewModel.chatIdFor(
          companyId: 'co-1',
          fieldUserId: 'field-1',
          supplierId: 'sup-1',
        ),
        ChatIdUtils.buildChatId(
          companyId: 'co-1',
          fieldUserId: 'field-1',
          supplierId: 'sup-1',
        ),
      );
      expect(chatId, 'field-1_sup-1_co-1');
    });
  });

  group('FieldChatViewModel.watchConversations', () {
    test('stores threads and unread field-user count', () async {
      var notifies = 0;
      var loadingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) loadingOnFirst = viewModel.isLoadingThreads;
      });

      viewModel.watchConversations('co-1', 'field-1');
      expect(loadingOnFirst, isTrue);
      verify(() => chatRepo.watchFieldUserThreads('co-1', 'field-1')).called(1);

      threadsStream.add([
        _thread(unreadFieldUser: 2),
        _thread(chatId: 'other', unreadFieldUser: 3),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.isLoadingThreads, isFalse);
      expect(viewModel.threads, hasLength(2));
      expect(viewModel.unreadMessageCount, 5);
      expect(notifies, 2);
    });

    test('stream error sets errorMessage', () async {
      viewModel.watchConversations('co-1', 'field-1');
      threadsStream.addError(AppException('threads down'));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.errorMessage, 'threads down');
      expect(viewModel.isLoadingThreads, isFalse);
    });
  });

  group('FieldChatViewModel.startListening', () {
    test('marks read then stores streamed messages', () async {
      await viewModel.startListening(chatId, currentUserId: 'field-1');

      verify(() => chatRepo.markMessagesRead(chatId, 'field-1')).called(1);
      verify(() => chatRepo.markThreadReadForFieldUser(chatId)).called(1);

      messagesStream.add([_message(), _message(id: 'msg-2')]);
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.isLoadingMessages, isFalse);
      expect(viewModel.messages, hasLength(2));
    });

    test('does not resubscribe for the same active thread', () async {
      await viewModel.startListening(chatId, currentUserId: 'field-1');
      await viewModel.startListening(chatId, currentUserId: 'field-1');

      verify(() => chatRepo.watchThreadMessages(chatId)).called(1);
    });

    test('message stream error sets errorMessage', () async {
      await viewModel.startListening(chatId, currentUserId: 'field-1');
      messagesStream.addError(Exception('messages down'));
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.errorMessage, contains('messages down'));
      expect(viewModel.isLoadingMessages, isFalse);
    });

    test('mark-read failure propagates and skips the message watch', () async {
      when(() => chatRepo.markMessagesRead(any(), any()))
          .thenThrow(AppException('denied'));

      await expectLater(
        viewModel.startListening(chatId, currentUserId: 'field-1'),
        throwsA(isA<AppException>()),
      );
      verifyNever(() => chatRepo.watchThreadMessages(any()));
      expect(viewModel.isLoadingMessages, isTrue);
    });
  });

  group('FieldChatViewModel.openThread', () {
    test('ensures the thread then starts listening', () async {
      await viewModel.openThread(
        companyId: 'co-1',
        fieldUserId: 'field-1',
        fieldUserName: 'Ali Raza',
        supplierId: 'sup-1',
        supplierName: 'Cement House',
      );

      final thread = verify(() => chatRepo.ensureThread(captureAny()))
          .captured
          .single as ChatThreadModel;
      expect(thread.chatId, chatId);
      expect(thread.supplierName, 'Cement House');
      verify(() => chatRepo.watchThreadMessages(chatId)).called(1);
    });

    test('ensureThread failure propagates and skips listening', () async {
      when(() => chatRepo.ensureThread(any()))
          .thenThrow(AppException('cannot open'));

      await expectLater(
        viewModel.openThread(
          companyId: 'co-1',
          fieldUserId: 'field-1',
          fieldUserName: 'Ali Raza',
          supplierId: 'sup-1',
          supplierName: 'Cement House',
        ),
        throwsA(isA<AppException>()),
      );
      verifyNever(() => chatRepo.watchThreadMessages(any()));
    });
  });

  group('FieldChatViewModel.sendMessage', () {
    test('empty text without an image returns false', () async {
      expect(await sendDefault(content: '   '), isFalse);
      verifyNever(() => chatRepo.sendChatMessage(any()));
    });

    test('success sends, updates the thread, and notifies the supplier',
        () async {
      var notifies = 0;
      var sendingOnFirst = false;
      viewModel.addListener(() {
        notifies++;
        if (notifies == 1) sendingOnFirst = viewModel.isSending;
      });

      expect(await sendDefault(content: '  Need 50 bags  '), isTrue);
      expect(sendingOnFirst, isTrue);
      expect(viewModel.isSending, isFalse);
      expect(notifies, 2);

      final sent = verify(() => chatRepo.sendChatMessage(captureAny()))
          .captured
          .single as ChatMessageModel;
      expect(sent.content, 'Need 50 bags');
      expect(sent.chatId, chatId);
      expect(sent.receiverId, 'sup-1');

      verify(
        () => chatRepo.updateThreadAfterMessage(
          chatId: chatId,
          companyId: 'co-1',
          lastMessage: 'Need 50 bags',
          lastSenderId: 'field-1',
          fieldUserId: 'field-1',
          supplierId: 'sup-1',
          fieldUserName: 'Ali Raza',
        ),
      ).called(1);
      verify(
        () => notifications.notifyChatMessage(
          recipientUserId: 'sup-1',
          senderName: 'Ali Raza',
          preview: 'Need 50 bags',
          chatId: chatId,
          companyId: 'co-1',
          fieldUserId: 'field-1',
          fieldUserName: 'Ali Raza',
          supplierId: 'sup-1',
          supplierName: 'Cement House',
        ),
      ).called(1);
    });

    test('image-only preview is Photo', () async {
      expect(
        await sendDefault(
          content: '   ',
          attachmentUrl: 'https://cdn.example/p.jpg',
        ),
        isTrue,
      );
      final sent = verify(() => chatRepo.sendChatMessage(captureAny()))
          .captured
          .single as ChatMessageModel;
      expect(sent.content, isEmpty);
      verify(
        () => chatRepo.updateThreadAfterMessage(
          chatId: chatId,
          companyId: 'co-1',
          lastMessage: 'Photo',
          lastSenderId: 'field-1',
          fieldUserId: 'field-1',
          supplierId: 'sup-1',
          fieldUserName: 'Ali Raza',
        ),
      ).called(1);
    });

    test('repository failure sets errorMessage and returns false', () async {
      when(() => chatRepo.sendChatMessage(any()))
          .thenThrow(AppException('send denied'));

      expect(await sendDefault(), isFalse);
      expect(viewModel.isSending, isFalse);
      expect(viewModel.errorMessage, 'send denied');
    });
  });

  group('FieldChatViewModel.closeThread', () {
    test('clears messages and ignores later stream events', () async {
      await viewModel.startListening(chatId, currentUserId: 'field-1');
      messagesStream.add([_message()]);
      await Future<void>.delayed(Duration.zero);

      var notifies = 0;
      viewModel.addListener(() => notifies++);
      viewModel.closeThread();

      expect(viewModel.messages, isEmpty);
      expect(notifies, 0);

      messagesStream.add([_message(id: 'late')]);
      await Future<void>.delayed(Duration.zero);
      expect(viewModel.messages, isEmpty);
    });
  });

  group('FieldChatViewModel.clearError', () {
    test('clears errorMessage', () async {
      viewModel.watchConversations('co-1', 'field-1');
      threadsStream.addError(Exception('offline'));
      await Future<void>.delayed(Duration.zero);

      viewModel.clearError();
      expect(viewModel.errorMessage, isNull);
    });
  });
}
