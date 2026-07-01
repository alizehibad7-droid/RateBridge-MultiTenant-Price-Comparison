import 'package:flutter/material.dart';

/// Rounded chat image bubble, tappable for fullscreen view.
class ChatAttachmentImage extends StatelessWidget {
  final String imageUrl;
  final double maxWidth;
  final double maxHeight;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  const ChatAttachmentImage({
    super.key,
    required this.imageUrl,
    required this.onTap,
    this.maxWidth = 220,
    this.maxHeight = 220,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return SizedBox(
                  width: maxWidth * 0.6,
                  height: 120,
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                width: maxWidth * 0.6,
                height: 120,
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
