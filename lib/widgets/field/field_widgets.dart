// MVVM: Widgets — pure presentation, no business logic.

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../constants/app_colors.dart';
import '../../models/order_model.dart';
import '../../models/material_listing.dart';

/// Full-screen status layout shared by Pending / Rejected / Deactivated
/// field user screens. Centers an icon, title, message, and optional
/// action button.
class FieldStatusScaffold extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final Widget? action;

  const FieldStatusScaffold({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor = AppColors.fieldAccent,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 40),
                ),
                const SizedBox(height: 24),
                Text(title, style: AppTextStyles.h1, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: AppTextStyles.bodyMuted,
                  textAlign: TextAlign.center,
                ),
                if (action != null) ...[
                  const SizedBox(height: 28),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Marketplace material card — shown in the home/search grid.
class MaterialListingCard extends StatelessWidget {
  final MaterialListing material;
  final VoidCallback onTap;
  final VoidCallback onCompare;

  const MaterialListingCard({
    super.key,
    required this.material,
    required this.onTap,
    required this.onCompare,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: appCardDecoration(shadow: AppShadows.card),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.fieldAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.construction,
                      color: AppColors.fieldAccent, size: 20),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.star, color: AppColors.warning, size: 14),
                    const SizedBox(width: 2),
                    Text(material.supplierRating.toStringAsFixed(1),
                        style: AppTextStyles.bodyMuted),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(material.materialName, style: AppTextStyles.h3),
            const SizedBox(height: 2),
            Text(material.supplierName, style: AppTextStyles.bodyMuted),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Rs ${material.pricePerUnit.toStringAsFixed(0)}',
                          style: AppTextStyles.h3
                              .copyWith(color: AppColors.fieldAccent),
                        ),
                        TextSpan(
                          text: ' / ${material.unit}',
                          style: AppTextStyles.bodyMuted,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onCompare,
                  icon: const Icon(Icons.compare_arrows,
                      size: 18, color: AppColors.textSecondary),
                  tooltip: 'Compare rates',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(
              material.stock > 0 ? '${material.stock} in stock' : 'Out of stock',
              style: AppTextStyles.bodyMuted.copyWith(
                color: material.stock > 0
                    ? AppColors.success
                    : AppColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact row showing one supplier's offer in the compare-rates list.
class CompareRateRow extends StatelessWidget {
  final MaterialListing material;
  final bool isBestPrice;
  final VoidCallback onSelect;

  const CompareRateRow({
    super.key,
    required this.material,
    required this.onSelect,
    this.isBestPrice = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: appCardDecoration(
        shadow: AppShadows.card,
        borderColor: isBestPrice ? AppColors.success : AppColors.border,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.supplierAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                color: AppColors.supplierAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(material.supplierName, style: AppTextStyles.h3),
                    if (isBestPrice) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Text(
                          'Best price',
                          style: TextStyle(
                              color: AppColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.star, color: AppColors.warning, size: 12),
                    const SizedBox(width: 2),
                    Text(material.supplierRating.toStringAsFixed(1),
                        style: AppTextStyles.bodyMuted),
                    const SizedBox(width: 8),
                    Text(
                      material.stock > 0
                          ? '${material.stock} ${material.unit}s in stock'
                          : 'Out of stock',
                      style: AppTextStyles.bodyMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rs ${material.pricePerUnit.toStringAsFixed(0)}',
                style: AppTextStyles.h3.copyWith(color: AppColors.fieldAccent),
              ),
              Text('/ ${material.unit}', style: AppTextStyles.bodyMuted),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: material.stock > 0 ? onSelect : null,
            icon: const Icon(Icons.arrow_forward_ios, size: 14),
          ),
        ],
      ),
    );
  }
}

/// Order list tile with status chip — used in "My Orders".
class FieldOrderTile extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onTap;

  const FieldOrderTile({super.key, required this.order, this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = StatusBadgeStyle.of(order.status);
    final displayStatus = order.status.isEmpty 
        ? 'Unknown' 
        : order.status[0].toUpperCase() + order.status.substring(1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: appCardDecoration(shadow: AppShadows.card),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.fieldAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.local_shipping_outlined,
                  color: AppColors.fieldAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.materialName, style: AppTextStyles.h3),
                  Text(
                    '${order.quantity.toStringAsFixed(0)} ${order.unit} · ${order.supplierName}',
                    style: AppTextStyles.bodyMuted,
                  ),
                  Text(order.siteLocation ?? 'No location', style: AppTextStyles.bodyMuted),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: style.bg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    displayStatus,
                    style: TextStyle(
                        color: style.fg,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 6),
                Text('Rs ${order.totalAmount.toStringAsFixed(0)}',
                    style: AppTextStyles.h3),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StatusBadgeStyle {
  final Color fg;
  final Color bg;

  StatusBadgeStyle({required this.fg, required this.bg});

  factory StatusBadgeStyle.of(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
      case 'active':
      case 'approved':
      case 'success':
        return StatusBadgeStyle(fg: AppColors.success, bg: AppColors.successBg);
      case 'pending':
      case 'pending_approval':
      case 'waiting':
        return StatusBadgeStyle(fg: AppColors.warning, bg: AppColors.warning.withValues(alpha: 0.1));
      case 'rejected':
      case 'cancelled':
      case 'failed':
        return StatusBadgeStyle(fg: AppColors.danger, bg: AppColors.dangerBg);
      default:
        return StatusBadgeStyle(fg: AppColors.textSecondary, bg: AppColors.surface);
    }
  }
}
