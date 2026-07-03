// MVVM: Widgets — pure presentation, no business logic.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/admin_theme.dart';
import '../../utils/chat_image_utils.dart';

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
    this.color = AdminColors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AdminColors.navy,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AdminTheme.mutedStyle(size: 12)),
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
        Text(title, style: AdminTheme.titleStyle()),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

/// Status pill for admin lists.
class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final style = AdminTheme.statusColors(status);
    final label = status.isEmpty
        ? status
        : status[0].toUpperCase() + status.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
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
          Icon(icon, size: 40, color: AdminColors.textGrey),
          const SizedBox(height: 12),
          Text(
            message,
            style: AdminTheme.mutedStyle(),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Approve / Reject action row used on pending approval cards.
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
          decoration: AdminTheme.inputDecoration(
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
            child: Text(
              'Reject',
              style: GoogleFonts.plusJakartaSans(color: AdminColors.red),
            ),
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
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Reject'),
            style: AdminTheme.destructiveButtonStyle(),
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
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.check, size: 16),
            label: const Text('Approve'),
            style: AdminTheme.primaryButtonStyle(height: 46),
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
        AdminSectionLabel(title),
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
            child: Text(label, style: AdminTheme.mutedStyle(size: 12)),
          ),
          Expanded(
            child: Text(
              display,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AdminColors.navy,
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
      return Text('—', style: AdminTheme.mutedStyle(size: 13));
    }
    final chipColor = color ?? AdminColors.navy;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: chipColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: chipColor.withValues(alpha: 0.25)),
          ),
          child: Text(
            item,
            style: GoogleFonts.plusJakartaSans(
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
            style: AdminTheme.mutedStyle(size: 11),
          ),
          const SizedBox(height: 6),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Material(
              color: AdminColors.screenBg,
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
                    border: Border.all(color: AdminColors.border),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined,
              size: 22, color: AdminColors.textGrey),
          const SizedBox(height: 4),
          Text('Not uploaded', style: AdminTheme.mutedStyle(size: 10)),
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

/// White card container matching admin panel style.
class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: AdminTheme.cardDecoration(),
      child: child,
    );
  }
}
