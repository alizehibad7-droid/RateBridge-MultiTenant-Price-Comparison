// MVVM: Widgets — pure presentation, no business logic.

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../utils/chat_image_utils.dart';
import '../../constants/app_colors.dart';
import '../status_badge.dart';

/// Compact stat card for the admin dashboard grid.
class AdminStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const AdminStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppColors.adminAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appCardDecoration(shadow: AppShadows.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(value, style: AppTextStyles.h1.copyWith(fontSize: 24)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodyMuted),
        ],
      ),
    );
  }
}

/// Section header with optional trailing action.
class AdminSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AdminSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.h2),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!,
                style: const TextStyle(color: AppColors.adminAccent)),
          ),
      ],
    );
  }
}

/// Status pill using the shared StatusBadgeStyle color mapping.
class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final style = StatusBadgeStyle.of(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          color: style.fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Placeholder shown when a list is empty.
class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(message,
              style: AppTextStyles.bodyMuted, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Approve / Reject action row used on pending approval cards.
/// Reject opens a dialog requiring a reason before calling [onReject].
class ApprovalActions extends StatelessWidget {
  final VoidCallback onApprove;
  final ValueChanged<String> onReject;
  final bool isLoading;

  const ApprovalActions({
    super.key,
    required this.onApprove,
    required this.onReject,
    this.isLoading = false,
  });

  Future<void> _showRejectDialog(BuildContext context) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject application'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Reason for rejection (shown to the applicant)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Reject',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty) {
      onReject(reason);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : () => _showRejectDialog(context),
            icon: const Icon(Icons.close, size: 16, color: AppColors.danger),
            label: const Text('Reject',
                style: TextStyle(color: AppColors.danger)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.danger),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onApprove,
            icon: isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.check, size: 16),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

/// Titled block inside an admin approval card.
class AdminApprovalSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const AdminApprovalSection({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }
}

/// Label + value row for admin approval detail panels.
class AdminDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final int maxLines;

  const AdminDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.maxLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    final display = value.trim().isEmpty ? '—' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              display,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal chip list for coverage areas, categories, etc.
class AdminChipList extends StatelessWidget {
  final List<String> items;
  final Color? color;

  const AdminChipList({
    super.key,
    required this.items,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('—', style: TextStyle(fontSize: 13, color: AppColors.textSecondary));
    }
    final chipColor = color ?? AppColors.primary;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: chipColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: chipColor.withValues(alpha: 0.25)),
          ),
          child: Text(
            item,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: chipColor,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// One tappable document thumbnail; opens fullscreen via [ChatImageUtils].
class AdminDocumentThumbnail extends StatelessWidget {
  final String label;
  final String? imageUrl;

  const AdminDocumentThumbnail({
    super.key,
    required this.label,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: hasImage
                    ? () => ChatImageUtils.showFullscreen(
                          context,
                          imageUrl: imageUrl,
                        )
                    : null,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: hasImage
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const _MissingDocPlaceholder(),
                            ),
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.zoom_in,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        )
                      : const _MissingDocPlaceholder(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingDocPlaceholder extends StatelessWidget {
  const _MissingDocPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined,
              size: 22, color: AppColors.textMuted),
          SizedBox(height: 4),
          Text('Not uploaded',
              style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

/// Row of document thumbnails with consistent spacing.
class AdminDocumentThumbnailRow extends StatelessWidget {
  final List<({String label, String? url})> documents;

  const AdminDocumentThumbnailRow({super.key, required this.documents});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < documents.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          AdminDocumentThumbnail(
            label: documents[i].label,
            imageUrl: documents[i].url,
          ),
        ],
      ],
    );
  }
}
