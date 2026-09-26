import '../models/chat_message_model.dart';
import '../models/chat_thread_model.dart';
import '../services/firestore_service.dart';

class ChatRepository {
  final FirestoreService _firestoreService;

  ChatRepository(this._firestoreService);

  Stream<List<ChatMessageModel>> retrieveChatHistory(String uid1, String uid2) {
    return _firestoreService.streamChats(uid1, uid2);
  }

  Stream<List<ChatThreadModel>> watchFieldUserThreads(
    String companyId,
    String fieldUserId,
  ) {
    return _firestoreService.streamFieldUserChatThreads(companyId, fieldUserId);
  }

  Stream<List<ChatMessageModel>> watchThreadMessages(String chatId) {
    return _firestoreService.streamChatMessages(chatId);
  }

  Future<void> ensureThread(ChatThreadModel thread) async {
    await _firestoreService.ensureChatThread(thread);
  }

  Future<void> sendChatMessage(ChatMessageModel message) async {
    await _firestoreService.saveChatMessage(message);
  }

  Future<void> updateThreadAfterMessage({
    required String chatId,
    required String companyId,
    required String lastMessage,
    required String lastSenderId,
    required String fieldUserId,
    required String supplierId,
    String? fieldUserName,
  }) async {
    await _firestoreService.updateChatThreadAfterMessage(
      chatId: chatId,
      companyId: companyId,
      lastMessage: lastMessage,
      lastSenderId: lastSenderId,
      fieldUserId: fieldUserId,
      supplierId: supplierId,
      fieldUserName: fieldUserName,
    );
  }

  Future<void> markThreadReadForFieldUser(String chatId) async {
    await _firestoreService.markChatThreadReadForFieldUser(chatId);
  }

  Stream<List<ChatThreadModel>> watchSupplierThreads(String supplierId) {
    return _firestoreService.streamSupplierChatThreads(supplierId);
  }

  Future<void> markThreadReadForSupplier(String chatId) async {
    await _firestoreService.markChatThreadReadForSupplier(chatId);
  }

  Future<void> markMessagesRead(String chatId, String currentUserId) async {
    await _firestoreService.markChatMessagesRead(chatId, currentUserId);
  }
}
