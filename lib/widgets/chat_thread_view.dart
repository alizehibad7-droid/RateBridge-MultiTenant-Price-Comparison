import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/chat_viewmodel.dart';
import '../widgets/chat_bubble_widget.dart';

class ChatThreadView extends StatefulWidget {
  final String orderId;
  final String currentUserRole;
  final String currentUserUid;

  const ChatThreadView({
    super.key,
    required this.orderId,
    required this.currentUserRole,
    required this.currentUserUid,
  });

  @override
  State<ChatThreadView> createState() => _ChatThreadViewState();
}

class _ChatThreadViewState extends State<ChatThreadView> {
  final _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatViewModel>().openChatThread(widget.orderId, widget.currentUserUid);
    });
  }

  void _handleSend() {
    if (_messageController.text.trim().isNotEmpty) {
      context.read<ChatViewModel>().sendMessage(widget.orderId, _messageController.text.trim());
      _messageController.clear();
    }
  }

  Future<void> _handleImage() async {
    // Image attachments are handled in FieldChatThreadView / SupplierChatThreadView.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Order #${widget.orderId.substring(0, 8)}", style: const TextStyle(fontSize: 14)),
            const Text("Field User: Raza Jamil", style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Chip(
              label: const Text("In Progress", style: TextStyle(fontSize: 10, color: Colors.white)),
              backgroundColor: Colors.blue.withOpacity(0.5),
            ),
          ),
        ],
      ),
      body: Consumer<ChatViewModel>(
        builder: (context, vm, child) {
          return Column(
            children: [
              if (vm.isChatLocked)
                Container(
                  width: double.infinity,
                  color: Colors.amber.withOpacity(0.2),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: const Text(
                    "This order is complete. Chat is read-only.",
                    style: TextStyle(color: Colors.amber, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(
                child: vm.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: vm.messages.length,
                        itemBuilder: (context, index) {
                          final msg = vm.messages[vm.messages.length - 1 - index];
                          final isMe = msg.senderId == widget.currentUserUid || msg.senderId == 'me';
                          return Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              ChatBubbleWidget(text: msg.content, isSelf: isMe),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "${msg.timestamp.hour}:${msg.timestamp.minute}",
                                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.done_all, size: 12, color: Colors.blue),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              if (!vm.isChatLocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E293B),
                    border: Border(top: BorderSide(color: Colors.white10)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.image, color: Colors.blue),
                        onPressed: _handleImage,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "Type a message...",
                            hintStyle: const TextStyle(color: Colors.white38),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: _handleSend,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}
