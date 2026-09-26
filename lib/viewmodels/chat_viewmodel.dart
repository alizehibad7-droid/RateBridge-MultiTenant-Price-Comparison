import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_message_model.dart';
import '../models/chat_thread_model.dart';
import '../repositories/chat_repository.dart';
import '../utils/chat_image_utils.dart';

/// Real-time chat thread messaging backed by Firestore.
class ChatViewModel extends ChangeNotifier {
  final ChatRepository _chatRepo;

  StreamSubscription<List<ChatMessageModel>>? _messagesSubscription;
  StreamSubscription<List<ChatThreadModel>>? _threadsSubscription;
  String? _activeChatId;

  List<ChatMessageModel> _messages = [];
  List<ChatThreadModel> _threads = [];
  bool _isLoading = false;
  bool _isLoadingMessages = false;
  bool _isSending = false;
  String? _errorMessage;

  ChatViewModel(this._chatRepo);

  List<ChatMessageModel> get messages => _messages;
  List<ChatThreadModel> get threads => _threads;
  bool get isLoading => _isLoading;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isSending => _isSending;
  bool get isChatLocked => false;
  String? get errorMessage => _errorMessage;

  int get unreadMessageCount =>
      _threads.fold(0, (total, thread) => total + thread.unreadSupplier);

  void watchSupplierThreads(String supplierId) {
    _threadsSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _threadsSubscription = _chatRepo.watchSupplierThreads(supplierId).listen(
      (data) {
        _threads = data;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> openChatThread(String chatId, String currentUserUid) async {
    await startListening(chatId, currentUserId: currentUserUid);
  }

  /// Subscribes to `/chats/{chatId}/messages` ordered by timestamp ascending.
  Future<void> startListening(String chatId, {required String currentUserId}) async {
    if (_activeChatId == chatId && _messagesSubscription != null) return;

    _messagesSubscription?.cancel();
    _activeChatId = chatId;
    _messages = [];
    _isLoadingMessages = true;
    _errorMessage = null;
    notifyListeners();

    await markRead(chatId, currentUserId);

    _messagesSubscription = _chatRepo.watchThreadMessages(chatId).listen(
      (data) {
        _messages = data;
        _isLoadingMessages = false;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = e.toString();
        _isLoadingMessages = false;
        notifyListeners();
      },
    );
  }

  Future<bool> sendMessage(
    String chatId,
    String text, [
    String senderId = '',
    String senderName = '',
    String receiverId = '',
    String? companyId,
    String? attachmentUrl,
  ]) async {
    final trimmed = text.trim();
    final hasImage = attachmentUrl != null && attachmentUrl.isNotEmpty;
    if (trimmed.isEmpty && !hasImage) return false;

    _isSending = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final message = ChatMessageModel(
        id: '',
        chatId: chatId,
        companyId: companyId,
        senderId: senderId,
        senderName: senderName,
        receiverId: receiverId,
        content: trimmed,
        timestamp: DateTime.now(),
        attachmentUrl: attachmentUrl,
        isRead: false,
      );
      await _chatRepo.sendChatMessage(message);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  static String threadPreview({required String text, bool hasImage = false}) =>
      ChatImageUtils.threadPreview(text: text, hasImage: hasImage);

  Future<void> markRead(String chatId, String currentUserId) async {
    await _chatRepo.markMessagesRead(chatId, currentUserId);
  }

  void stopListening() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
    _activeChatId = null;
    _messages = [];
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _threadsSubscription?.cancel();
    super.dispose();
  }
}
