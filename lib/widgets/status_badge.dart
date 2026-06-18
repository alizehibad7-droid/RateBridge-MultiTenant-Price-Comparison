import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/app_theme.dart';

class StatusBadgeStyle {
  final Color bg;
  final Color fg;
  const StatusBadgeStyle(this.bg, this.fg);

  static StatusBadgeStyle of(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'approved':
      case 'verified':
      case 'confirmed':
      case 'delivered':
      case 'linked':
      case 'onsite':
      case 'paid':
        return const StatusBadgeStyle(AppColors.successBg, AppColors.success);
      case 'pending':
      case 'pending review':
      case 'awaiting':
      case 'info_requested':
      case 'in progress':
      case 'in_progress':
        return const StatusBadgeStyle(AppColors.infoBg, AppColors.primary);
      case 'rejected':
      case 'deactivated':
      case 'suspended':
      case 'cancelled':
        return const StatusBadgeStyle(AppColors.dangerBg, AppColors.danger);
      default:
        return const StatusBadgeStyle(AppColors.infoBg, AppColors.primary);
    }
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final String status;

  const StatusBadge({super.key, required this.label, required this.status});

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
        label,
        style: TextStyle(
          color: style.fg,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class RatingStars extends StatelessWidget {
  final double value; // 0..5
  final double size;
  final Color color;

  const RatingStars({
    super.key,
    required this.value,
    this.size = 14,
    this.color = AppColors.warning,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        IconData icon;
        if (value >= i + 1) {
          icon = Icons.star;
        } else if (value > i && value < i + 1) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, size: size, color: color);
      }),
    );
  }
}
