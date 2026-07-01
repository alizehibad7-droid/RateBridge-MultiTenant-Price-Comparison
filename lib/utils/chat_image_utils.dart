import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// In-memory image selected for chat upload (works on web and mobile).
class PendingChatImage {
  final Uint8List bytes;
  final String? name;

  const PendingChatImage({required this.bytes, this.name});
}

/// Shared helpers for chat image pick, preview, and fullscreen view.
class ChatImageUtils {
  ChatImageUtils._();

  static final ImagePicker _picker = ImagePicker();

  static Future<ImageSource?> showSourceSheet(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<PendingChatImage?> pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    return PendingChatImage(bytes: bytes, name: picked.name);
  }

  static String threadPreview({required String text, bool hasImage = false}) {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) return trimmed;
    if (hasImage) return 'Photo';
    return '';
  }

  static void showFullscreen(
    BuildContext context, {
    String? imageUrl,
    Uint8List? imageBytes,
  }) {
    if ((imageUrl == null || imageUrl.isEmpty) && imageBytes == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => _ChatFullscreenImagePage(
          imageUrl: imageUrl,
          imageBytes: imageBytes,
        ),
      ),
    );
  }
}

class _ChatFullscreenImagePage extends StatelessWidget {
  final String? imageUrl;
  final Uint8List? imageBytes;

  const _ChatFullscreenImagePage({
    this.imageUrl,
    this.imageBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          child: imageBytes != null
              ? Image.memory(imageBytes!, fit: BoxFit.contain)
              : Image.network(
                  imageUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
        ),
      ),
    );
  }
}
