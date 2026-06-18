import '../models/chat_message_model.dart';
import '../services/firestore_service.dart';

class ChatRepository {
  final FirestoreService _firestoreService;

  ChatRepository(this._firestoreService);

  Stream<List<ChatMessageModel>> retrieveChatHistory(String uid1, String uid2) {
    return _firestoreService.streamChats(uid1, uid2);
  }

  Future<void> sendChatMessage(ChatMessageModel message) async {
    await _firestoreService.saveChatMessage(message);
  }
}
