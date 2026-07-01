import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme/supplier_theme.dart';
import '../../models/chat_message_model.dart';
import '../../models/chat_thread_model.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/cloudinary_service.dart';
import '../../services/notification_service.dart';
import '../../utils/chat_image_utils.dart';
import '../../utils/phone_launcher_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../widgets/chat_attachment_image.dart';
import '../../widgets/chat_pending_image_preview.dart';

class SupplierChatThreadView extends StatefulWidget {
  final ChatThreadModel thread;

  const SupplierChatThreadView({super.key, required this.thread});

  @override
  State<SupplierChatThreadView> createState() => _SupplierChatThreadViewState();
}

class _SupplierChatThreadViewState extends State<SupplierChatThreadView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late final String _supplierId;
  late final String _supplierName;
  late final ChatViewModel _chatVm;
  PendingChatImage? _pendingImage;
  String? _fieldUserPhone;
  String? _fieldUserName;

  bool get _canSend =>
      _messageController.text.trim().isNotEmpty || _pendingImage != null;

  @override
  void initState() {
    super.initState();
    _supplierId = context.read<AuthViewModel>().user!.uid;
    _supplierName = context.read<AuthViewModel>().user?.name ?? 'Supplier';
    _chatVm = context.read<ChatViewModel>();
    _messageController.addListener(_onComposerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openThread());
  }

  void _onComposerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openThread() async {
    final chatRepo = context.read<ChatRepository>();
    final userRepo = context.read<UserRepository>();
    await _chatVm.startListening(
      widget.thread.chatId,
      currentUserId: _supplierId,
    );
    if (!mounted) return;
    await chatRepo.markThreadReadForSupplier(widget.thread.chatId);
    if (!mounted) return;

    try {
      final user = await userRepo.getUserDoc(widget.thread.fieldUserId);
      if (mounted) {
        setState(() {
          _fieldUserPhone = user.phone;
          _fieldUserName = user.name;
        });
      }
    } catch (_) {}
  }

  String get _headerName {
    if (widget.thread.fieldUserName.isNotEmpty) {
      return widget.thread.fieldUserName;
    }
    if (_fieldUserName != null && _fieldUserName!.trim().isNotEmpty) {
      return _fieldUserName!.trim();
    }
    return 'Field User';
  }

  Future<void> _callFieldUser() async {
    await PhoneLauncherUtils.dial(context, _fieldUserPhone);
  }

  Future<void> _pickImage() async {
    final source = await ChatImageUtils.showSourceSheet(context);
    if (source == null || !mounted) return;

    final picked = await ChatImageUtils.pickImage(source);
    if (picked != null && mounted) {
      setState(() => _pendingImage = picked);
    }
  }

  void _removePendingImage() {
    setState(() => _pendingImage = null);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final pending = _pendingImage;
    if (text.isEmpty && pending == null) return;

    String? attachmentUrl;
    if (pending != null) {
      attachmentUrl = await CloudinaryService.uploadImageBytes(
        bytes: pending.bytes,
        folder: 'ratebridge/chat',
        filename: pending.name ?? 'chat.jpg',
      );
      if (!mounted) return;
      if (attachmentUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image upload failed. Please try again.')),
        );
        return;
      }
    }

    final chatRepo = context.read<ChatRepository>();
    final sent = await _chatVm.sendMessage(
      widget.thread.chatId,
      text,
      _supplierId,
      _supplierName,
      widget.thread.fieldUserId,
      widget.thread.companyId,
      attachmentUrl,
    );

    if (!sent || !mounted) return;

    final preview = ChatViewModel.threadPreview(
      text: text,
      hasImage: attachmentUrl != null,
    );

    await chatRepo.updateThreadAfterMessage(
      chatId: widget.thread.chatId,
      companyId: widget.thread.companyId,
      lastMessage: preview,
      lastSenderId: _supplierId,
      fieldUserId: widget.thread.fieldUserId,
      supplierId: _supplierId,
    );

    await context.read<NotificationService>().notifyChatMessage(
      recipientUserId: widget.thread.fieldUserId,
      senderName: _supplierName,
      preview: preview,
      chatId: widget.thread.chatId,
      companyId: widget.thread.companyId,
      fieldUserId: widget.thread.fieldUserId,
      fieldUserName: widget.thread.fieldUserName,
      supplierId: _supplierId,
      supplierName: _supplierName,
    );

    if (!mounted) return;
    _messageController.clear();
    setState(() => _pendingImage = null);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.removeListener(_onComposerChanged);
    _chatVm.stopListening();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: SupplierAppBar(
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _headerName,
              style: FieldTypography.titleMedium.copyWith(
                color: FieldColors.surfaceWhite,
                fontSize: 16,
              ),
            ),
            Text(
              widget.thread.companyId,
              style: FieldTypography.labelSmall.copyWith(
                color: FieldColors.surfaceWhite.withValues(alpha: 0.75),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_outlined),
            tooltip: 'Call field user',
            onPressed: _callFieldUser,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatViewModel>(
              builder: (context, vm, _) {
                if (vm.isLoadingMessages) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (vm.messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Say hello!',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: vm.messages.length,
                  itemBuilder: (context, index) {
                    final msg = vm.messages[index];
                    final isMe = msg.senderId == _supplierId;
                    return _SupplierChatBubble(
                      message: msg,
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: FieldColors.borderSubtle)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_pendingImage != null)
                  ChatPendingImagePreview(
                    imageBytes: _pendingImage!.bytes,
                    onRemove: _removePendingImage,
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: _chatVm.isSending ? null : _pickImage,
                      icon: const Icon(Icons.image_outlined),
                      color: FieldColors.primaryNavy,
                      tooltip: 'Attach image',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          filled: true,
                          fillColor: FieldColors.screenBackground,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: FieldColors.borderSubtle),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(color: FieldColors.borderSubtle),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                              color: FieldColors.primaryNavy,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Consumer<ChatViewModel>(
                      builder: (_, vm, __) => GestureDetector(
                        onTap: _canSend && !vm.isSending ? _sendMessage : null,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _canSend && !vm.isSending
                                ? FieldColors.primaryNavy
                                : FieldColors.primaryNavy.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: vm.isSending
                              ? const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierChatBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMe;

  const _SupplierChatBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = message.content.trim().isNotEmpty;
    final hasImage =
        message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 60 : 0,
        right: isMe ? 0 : 60,
        bottom: 8,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isMe ? FieldColors.primaryNavy : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 16),
            ),
            border: isMe ? null : Border.all(color: FieldColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (hasImage)
                ChatAttachmentImage(
                  imageUrl: message.attachmentUrl!,
                  onTap: () => ChatImageUtils.showFullscreen(
                    context,
                    imageUrl: message.attachmentUrl,
                  ),
                ),
              if (hasImage && hasText) const SizedBox(height: 6),
              if (hasText)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  DateFormat('hh:mm a').format(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.grey.shade400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
