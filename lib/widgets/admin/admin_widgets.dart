// MVVM: Widgets — pure presentation, no business logic.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/order_model.dart';
import '../../theme/admin_theme.dart';
import '../../utils/chat_image_utils.dart';
import '../../viewmodels/admin_viewmodel.dart';

/// Compact stat card for the admin dashboard grid.
class AdminStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const AdminStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = AdminColors.amber,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 12,
            vertical: isMobile ? 8 : 12,
          ),
          decoration: AdminTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isMobile ? 24 : 32,
                height: isMobile ? 24 : 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: isMobile ? 12 : 16),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isMobile ? 16 : 20,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.navy,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                label, 
                style: AdminTheme.mutedStyle(size: isMobile ? 9 : 10).copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section header with optional trailing action.
class AdminSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AdminSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: isMobile ? 16 : 18, color: AdminColors.navy),
              const SizedBox(width: 8),
            ],
            Text(title, style: AdminTheme.titleStyle(size: isMobile ? 13 : 15)),
          ],
        ),
        if (actionLabel != null)
          TextButton.icon(
            onPressed: onAction,
            icon: Icon(Icons.arrow_forward_rounded, size: isMobile ? 11 : 13),
            label: Text(actionLabel!, style: TextStyle(fontSize: isMobile ? 10 : 12)),
            style: TextButton.styleFrom(
              padding: isMobile ? const EdgeInsets.symmetric(horizontal: 6) : null,
              minimumSize: isMobile ? Size.zero : null,
              tapTargetSize: isMobile ? MaterialTapTargetSize.shrinkWrap : null,
            ),
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
        : status[0].toUpperCase() + status.substring(1).replaceAll('_', ' ');
        
    IconData statusIcon = Icons.info_outline_rounded;
    if (status == 'active' || status == 'confirmed' || status == 'approved' || status == 'success' || status == 'settled') statusIcon = Icons.check_circle_rounded;
    if (status == 'pending') statusIcon = Icons.hourglass_empty_rounded;
    if (status == 'rejected' || status == 'suspended' || status == 'failed') statusIcon = Icons.cancel_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 9, color: style.fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: style.fg,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder shown when a list is empty.
class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subMessage;

  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AdminColors.navy.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AdminColors.textGrey.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: AdminTheme.titleStyle(size: 16).copyWith(color: AdminColors.navy.withValues(alpha: 0.7)),
              textAlign: TextAlign.center,
            ),
            if (subMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                subMessage!,
                style: AdminTheme.mutedStyle(size: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
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
        title: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: AdminColors.red),
            const SizedBox(width: 10),
            const Text('Reject Application'),
          ],
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: AdminTheme.inputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'This will be shown to the applicant...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context, controller.text.trim());
            },
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('REJECT'),
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.red),
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
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : () => _showRejectDialog(context),
            icon: Icon(Icons.close_rounded, size: isMobile ? 14 : 16),
            label: Text('REJECT', style: TextStyle(fontSize: isMobile ? 10 : 12)),
            style: AdminTheme.destructiveButtonStyle(height: isMobile ? 36 : 40),
          ),
        ),
        SizedBox(width: isMobile ? 8 : 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onApprove,
            icon: isLoading
                ? SizedBox(
                    width: isMobile ? 12 : 14,
                    height: isMobile ? 12 : 14,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(Icons.check_rounded, size: isMobile ? 14 : 16),
            label: Text('APPROVE', style: TextStyle(fontSize: isMobile ? 10 : 12)),
            style: AdminTheme.primaryButtonStyle(height: isMobile ? 36 : 40).copyWith(
              backgroundColor: WidgetStateProperty.all(AdminColors.green),
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
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title.toUpperCase(), style: AdminTheme.sectionHeaderStyle(size: isMobile ? 9 : 10)),
        const SizedBox(height: 8),
        Container(
          padding: EdgeInsets.all(isMobile ? 8 : 10),
          decoration: BoxDecoration(
            color: AdminColors.screenBg.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AdminColors.border.withValues(alpha: 0.5)),
          ),
          child: Column(children: children),
        ),
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
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    final display = value.trim().isEmpty ? 'Not Provided' : value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isMobile ? 80 : 100,
            child: Text(label, style: AdminTheme.mutedStyle(size: isMobile ? 9 : 10).copyWith(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              display,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: isMobile ? 10 : 11,
                fontWeight: FontWeight.w700,
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
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    if (items.isEmpty) {
      return Text('None declared', style: AdminTheme.mutedStyle(size: isMobile ? 10 : 11).copyWith(fontStyle: FontStyle.italic));
    }
    final chipColor = color ?? AdminColors.navy;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: items.map((item) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8, vertical: 2),
          decoration: BoxDecoration(
            color: chipColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: chipColor.withValues(alpha: 0.2)),
          ),
          child: Text(
            item,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isMobile ? 8 : 9,
              fontWeight: FontWeight.w800,
              color: chipColor,
              letterSpacing: 0.3,
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
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.description_rounded, size: isMobile ? 9 : 10, color: AdminColors.textGrey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminTheme.mutedStyle(size: isMobile ? 7 : 8).copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Material(
              color: AdminColors.screenBg,
              borderRadius: BorderRadius.circular(8),
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
                    borderRadius: BorderRadius.circular(8),
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
                              loadingBuilder: (context, child, progress) =>
                                  progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.zoom_in_rounded,
                                  color: Colors.white,
                                  size: isMobile ? 10 : 14,
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
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_rounded,
              size: isMobile ? 16 : 20, color: AdminColors.textGrey.withValues(alpha: 0.5)),
          const SizedBox(height: 2),
          Text('NO DOCUMENT', style: AdminTheme.mutedStyle(size: isMobile ? 7 : 8).copyWith(fontWeight: FontWeight.bold)),
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
          if (i > 0) const SizedBox(width: 8),
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
/// Connected companies (for supplier detail) or connected suppliers (for CEO
/// detail), with each partner's shared orders.
class AdminConnectedPartnersSection extends StatelessWidget {
  final String title;
  final String emptyMessage;
  final Future<List<AdminPartnerLink>> future;
  final int maxOrdersShown;

  const AdminConnectedPartnersSection({
    super.key,
    required this.title,
    required this.future,
    this.emptyMessage = 'No connected partners yet.',
    this.maxOrdersShown = 5,
  });

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'approved':
        return AdminColors.green;
      case 'pending':
        return AdminColors.amber;
      case 'deactivated':
      case 'rejected':
      case 'suspended':
        return AdminColors.red;
      default:
        return AdminColors.textGrey;
    }
  }

  Color _orderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'confirmed':
      case 'accepted':
        return AdminColors.green;
      case 'pending':
      case 'cancellation_requested':
        return AdminColors.amber;
      case 'rejected':
      case 'cancelled':
        return AdminColors.red;
      default:
        return AdminColors.textGrey;
    }
  }

  String _formatDate(DateTime d) => DateFormat('dd MMM yyyy').format(d);

  String _formatAmount(double amount) {
    final fmt = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);
    return fmt.format(amount);
  }

  String _shortId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 8)}…';
  }

  Widget _statusPill(String status, Color color, {bool compact = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: compact ? 8 : 9,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _orderRow(OrderModel order, bool isMobile) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.materialName.trim().isEmpty
                      ? 'Order ${_shortId(order.orderId)}'
                      : order.materialName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: isMobile ? 10 : 11,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_shortId(order.orderId)} · ${_formatDate(order.createdAt)}',
                  style: AdminTheme.mutedStyle(size: isMobile ? 8 : 9),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatAmount(order.totalAmount),
            style: GoogleFonts.plusJakartaSans(
              fontSize: isMobile ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: AdminColors.navy,
            ),
          ),
          const SizedBox(width: 8),
          _statusPill(order.status, _orderStatusColor(order.status), compact: true),
        ],
      ),
    );
  }

  Widget _partnerCard(AdminPartnerLink link, bool isMobile) {
    final orders = link.orders;
    final shown = orders.take(maxOrdersShown).toList(growable: false);
    final remaining = orders.length - shown.length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AdminColors.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.partnerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: isMobile ? 12 : 13,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.navy,
                      ),
                    ),
                    if (link.subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        link.subtitle,
                        style: AdminTheme.mutedStyle(size: isMobile ? 9 : 10),
                      ),
                    ],
                  ],
                ),
              ),
              _statusPill(link.linkStatus, _statusColor(link.linkStatus)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 14, color: AdminColors.textGrey),
              const SizedBox(width: 4),
              Text(
                '${orders.length} order${orders.length == 1 ? '' : 's'}',
                style: AdminTheme.mutedStyle(size: isMobile ? 9 : 10)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (orders.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'No orders with this partner yet.',
                style: AdminTheme.mutedStyle(size: isMobile ? 9 : 10)
                    .copyWith(fontStyle: FontStyle.italic),
              ),
            )
          else ...[
            const SizedBox(height: 4),
            ...shown.map((o) => _orderRow(o, isMobile)),
            if (remaining > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '+$remaining more order${remaining == 1 ? '' : 's'}',
                  style: AdminTheme.mutedStyle(size: isMobile ? 9 : 10)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    return AdminApprovalSection(
      title: title,
      children: [
        FutureBuilder<List<AdminPartnerLink>>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            if (snap.hasError) {
              return Text(
                'Could not load connections.',
                style: AdminTheme.mutedStyle(size: isMobile ? 10 : 11)
                    .copyWith(color: AdminColors.red),
              );
            }
            final links = snap.data ?? const <AdminPartnerLink>[];
            if (links.isEmpty) {
              return Text(
                emptyMessage,
                style: AdminTheme.mutedStyle(size: isMobile ? 10 : 11)
                    .copyWith(fontStyle: FontStyle.italic),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${links.length} connected · '
                    '${links.fold<int>(0, (s, l) => s + l.orders.length)} orders',
                    style: AdminTheme.mutedStyle(size: isMobile ? 9 : 10)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                ...links.map((l) => _partnerCard(l, isMobile)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final String? title;

  const AdminCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    
    final effectivePadding = padding ?? EdgeInsets.all(isMobile ? 12 : 16);

    return Container(
      width: double.infinity,
      margin: margin,
      padding: effectivePadding,
      decoration: AdminTheme.cardDecoration().copyWith(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: title == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title!, style: AdminTheme.titleStyle(size: isMobile ? 14 : 15)),
                SizedBox(height: isMobile ? 10 : 12),
                child,
              ],
            ),
    );
  }
}
