import 'dart:io';
import 'package:flutter/material.dart';
import '../models/chat_message_model.dart';

class ChatViewModel extends ChangeNotifier {
  List<ChatMessageModel> _messages = [];
  bool _isSending = false;
  bool _isLoading = false;
  bool _isChatLocked = false;

  ChatViewModel() {
    _loadMockChats();
  }

  List<ChatMessageModel> get messages => _messages;
  bool get isSending => _isSending;
  bool get isLoading => _isLoading;
  bool get isChatLocked => _isChatLocked;

  void _loadMockChats() {
    _messages = [
      ChatMessageModel(
        id: 'MSG-001',
        senderId: 'FU-51',
        senderName: 'Raza Jamil',
        receiverId: 'SU-402',
        content: 'Salam. Can you confirm if you have 15 Tons of ASTM A615 Grade 60 Rebar available in Lahore warehouse for immediate transit?',
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      ChatMessageModel(
        id: 'MSG-002',
        senderId: 'SU-402',
        senderName: 'Amreli Steel Mill Distributor',
        receiverId: 'FU-51',
        content: 'Walaikum Assalam. Yes, the stock is active and fully approved by QA lab testings. Sourcing lead time is 3 days max.',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ];
    notifyListeners();
  }

  Future<void> loadSupplierChats(String supplierUid) async {
    _isLoading = true;
    notifyListeners();
    // Logic to load chat threads for a supplier
    await Future.delayed(const Duration(milliseconds: 500));
    _isLoading = false;
    notifyListeners();
  }

  Future<void> openChatThread(String orderId, String currentUserUid) async {
    _isLoading = true;
    notifyListeners();
    // Logic to reset unread count and load thread
    await Future.delayed(const Duration(milliseconds: 500));
    _isLoading = false;
    notifyListeners();
  }

  Future<void> sendMessage(String orderId, String text) async {
    // Implementation for sending text message
    final msg = ChatMessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'me', // Placeholder
      senderName: 'Me',
      receiverId: 'other',
      content: text,
      timestamp: DateTime.now(),
    );
    _messages.add(msg);
    notifyListeners();
  }

  Future<void> sendImage(String orderId, File imageFile) async {
    // Implementation for sending image message
  }

  Future<void> dispatchMessage(String text, String senderId, String senderName, String receiverId) async {
    final newMessage = ChatMessageModel(
      id: 'MSG-${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderName: senderName,
      receiverId: receiverId,
      content: text,
      timestamp: DateTime.now(),
    );

    _messages = [..._messages, newMessage];
    _isSending = true;
    notifyListeners();
    
    await Future.delayed(const Duration(milliseconds: 300));
    _isSending = false;
    notifyListeners();
  }
}
