import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../theme/ceo_theme.dart';

class SupplierPerformanceScorecard extends StatelessWidget {
  final String supplierId;
  final String? companyId;
  final double averageRating;

  const SupplierPerformanceScorecard({
    super.key,
    required this.supplierId,
    this.companyId,
    required this.averageRating,
  });

  @override
  Widget build(BuildContext context) {
    final firestore = context.read<FirestoreService>();

    return FutureBuilder<Map<String, dynamic>>(
      future: firestore.getSupplierStats(supplierId, companyId: companyId),
      builder: (context, statsSnap) {
        return FutureBuilder<int>(
          future: firestore.getSupplierDisputeCount(supplierId, companyId: companyId),
          builder: (context, disputeSnap) {
            final stats = statsSnap.data ?? {'totalFulfilled': 0, 'onTimeRate': 0.0};
            final disputeCount = disputeSnap.data ?? 0;
            final onTimeRate = stats['onTimeRate'] as double;
            final totalFulfilled = stats['totalFulfilled'] as int;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CeoColors.screenBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CeoColors.border.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PERFORMANCE SCORECARD', style: CeoTheme.sectionHeaderStyle()),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatItem(
                        label: 'Avg Rating',
                        value: averageRating.toStringAsFixed(1),
                        icon: Icons.star,
                        iconColor: CeoColors.amber,
                      ),
                      _StatItem(
                        label: 'On-Time',
                        value: '${onTimeRate.toStringAsFixed(0)}%',
                        icon: Icons.timer_outlined,
                        iconColor: CeoColors.green,
                      ),
                      _StatItem(
                        label: 'Fulfilled',
                        value: totalFulfilled.toString(),
                        icon: Icons.shopping_bag_outlined,
                        iconColor: CeoColors.navy,
                      ),
                      _StatItem(
                        label: 'Disputes',
                        value: disputeCount.toString(),
                        icon: Icons.gavel_outlined,
                        iconColor: disputeCount > 0 ? CeoColors.red : CeoColors.textGrey,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 4),
        Text(value, style: CeoTheme.titleStyle(size: 16)),
        Text(label, style: CeoTheme.mutedStyle(size: 10)),
      ],
    );
  }
}
