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
      child: Text(
        _label,
        style: GoogleFonts.plusJakartaSans(
          color: style.fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
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
          Text(
            'COMPANY INVITE CODE',
            style: CeoTheme.sectionHeaderStyle(),
          ),
          const SizedBox(height: 10),
          Text(
            inviteCode,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
              color: CeoColors.navy,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onCopy,
                  style: CeoTheme.primaryButtonStyle(height: 40),
                  child: const Text('Copy Code'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: isRegenerating ? null : onRegenerate,
                  style: CeoTheme.destructiveButtonStyle(height: 40),
                  child: isRegenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Regenerate'),
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

  const CeoStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: CeoTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: CeoColors.amber.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: CeoColors.amber, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: CeoColors.navy,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: CeoTheme.mutedStyle(size: 11),
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
            color: CeoColors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: const Border(
              left: BorderSide(color: CeoColors.amber, width: 4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.hourglass_top_rounded,
                    color: CeoColors.darkAmber, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '⏳ $count order(s) awaiting your approval',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CeoColors.navy,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: CeoColors.textGrey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Maps CEO order status to display label for approval cards.
bool isCeoAwaitingApproval(String status) =>
    status == AppConstants.statusPendingApproval;
