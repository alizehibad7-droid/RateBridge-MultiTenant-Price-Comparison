import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_constants.dart';
import '../../theme/ceo_theme.dart';

export '../admin/admin_widgets.dart' show AdminCard, StatusChip;

/// CEO order/status pill with panel theme colors.
class CeoStatusBadge extends StatelessWidget {
  final String status;

  const CeoStatusBadge({super.key, required this.status});

  String get _label {
    final normalized = status.toLowerCase().replaceAll('_', '');
    if (normalized == 'pendingapproval') return 'Awaiting Review';
    if (status.isEmpty) return status;
    return status
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  IconData get _icon {
    final s = status.toLowerCase();
    if (s.contains('pending')) return Icons.hourglass_empty_rounded;
    if (s.contains('accept') || s.contains('approved') || s.contains('confirmed')) return Icons.check_circle_outline_rounded;
    if (s.contains('reject') || s.contains('cancel') || s.contains('removed')) return Icons.cancel_outlined;
    if (s.contains('progress')) return Icons.pending_rounded;
    if (s.contains('deliver')) return Icons.local_shipping_outlined;
    return Icons.info_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase().replaceAll('_', '');
    final paletteKey = normalized == 'pendingapproval' ? 'pending' : status;
    final style = CeoTheme.statusColors(paletteKey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: style.fg),
          const SizedBox(width: 4),
          Text(
            _label,
            style: GoogleFonts.plusJakartaSans(
              color: style.fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Amber left-accent invite code card for the CEO dashboard.
class CeoInviteCodeCard extends StatelessWidget {
  final String inviteCode;
  final VoidCallback onCopy;
  final VoidCallback onRegenerate;
  final bool isRegenerating;

  const CeoInviteCodeCard({
    super.key,
    required this.inviteCode,
    required this.onCopy,
    required this.onRegenerate,
    this.isRegenerating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CeoTheme.cardDecoration().copyWith(
        border: const Border(
          left: BorderSide(color: CeoColors.amber, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.key_rounded, color: CeoColors.amber, size: 18),
              const SizedBox(width: 8),
              Text(
                'COMPANY INVITE CODE',
                style: CeoTheme.sectionHeaderStyle(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: CeoColors.screenBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                inviteCode,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  color: CeoColors.navy,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.content_copy_rounded, size: 16),
                  label: const Text('Copy Code'),
                  style: CeoTheme.primaryButtonStyle(height: 44),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isRegenerating ? null : onRegenerate,
                  icon: isRegenerating ? const SizedBox.shrink() : const Icon(Icons.refresh_rounded, size: 16),
                  label: isRegenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Regenerate'),
                  style: CeoTheme.destructiveButtonStyle(height: 44),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 2x2 stat card for CEO dashboard.
class CeoStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const CeoStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = CeoColors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CeoTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: CeoColors.navy,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CeoTheme.mutedStyle(size: 11).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Tappable pending-orders banner on CEO dashboard.
class CeoPendingApprovalBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const CeoPendingApprovalBanner({
    super.key,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: CeoColors.amber.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CeoColors.amber.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: CeoColors.amber,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.priority_high_rounded, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Approvals Required',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: CeoColors.navy,
                        ),
                      ),
                      Text(
                        '$count order(s) waiting for your review',
                        style: CeoTheme.mutedStyle(size: 12).copyWith(color: CeoColors.darkAmber),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: CeoColors.amber, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Maps CEO order status to display label for approval cards.
bool isCeoAwaitingApproval(String status) {
  return status == AppConstants.statusPendingApproval;
}
