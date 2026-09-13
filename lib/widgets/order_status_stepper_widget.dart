import 'package:flutter/material.dart';

import '../theme/field_theme.dart';
import '../views/field_user/orders/field_order_status.dart';

/// Horizontal progress stepper for field-user order statuses.
class OrderStatusStepperWidget extends StatelessWidget {
  final String status;

  const OrderStatusStepperWidget({super.key, required this.status});

  static const _steps = [
    'Placed',
    'Accepted',
    'Delivered',
    'Confirmed',
  ];

  @override
  Widget build(BuildContext context) {
    final current = FieldOrderStatus.stepIndex(status);
    final isTerminal = FieldOrderStatus.isTerminal(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FieldSpacing.md),
      decoration: FieldTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Status', style: FieldTypography.titleMedium),
              const Spacer(),
              _OrderStatusPill(status: status),
            ],
          ),
          if (isTerminal) ...[
            const SizedBox(height: FieldSpacing.md),
            Text(
              _terminalMessage(status),
              style: FieldTypography.bodyMedium.copyWith(
                color: FieldColors.statusDanger,
              ),
            ),
          ] else ...[
            const SizedBox(height: FieldSpacing.lg),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_steps.length, (index) {
                  final isComplete = current >= 0 && index < current;
                  final isCurrent = index == current;
                  return Row(
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isComplete || isCurrent
                                  ? FieldColors.primaryNavy
                                  : FieldColors.borderSubtle,
                            ),
                            child: isComplete
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: FieldColors.surfaceWhite,
                                  )
                                : isCurrent
                                    ? Container(
                                        margin: const EdgeInsets.all(
                                          FieldSpacing.sm,
                                        ),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: FieldColors.accentAmber,
                                        ),
                                      )
                                    : null,
                          ),
                          const SizedBox(height: FieldSpacing.xs),
                          SizedBox(
                            width: 72,
                            child: Text(
                              _steps[index],
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: FieldTypography.labelSmall.copyWith(
                                fontSize: 9,
                                color: isCurrent
                                    ? FieldColors.primaryNavy
                                    : FieldColors.textMuted,
                                fontWeight: isCurrent
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (index < _steps.length - 1)
                        Container(
                          width: 28,
                          height: 2,
                          margin: const EdgeInsets.only(
                            bottom: FieldSpacing.lg,
                            left: FieldSpacing.xs,
                            right: FieldSpacing.xs,
                          ),
                          color: isComplete
                              ? FieldColors.primaryNavy
                              : FieldColors.borderSubtle,
                        ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _terminalMessage(String status) {
    if (FieldOrderStatus.normalize(status) == 'cancelled') {
      return 'This order was cancelled.';
    }
    return 'This order was rejected by the supplier.';
  }
}

class _OrderStatusPill extends StatelessWidget {
  final String status;

  const _OrderStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = FieldOrderStatus.colorsFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FieldSpacing.sm,
        vertical: FieldSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(FieldRadius.chip),
      ),
      child: Text(
        FieldOrderStatus.displayLabel(status),
        style: FieldTypography.labelSmall.copyWith(
          color: colors.fg,
          fontSize: 10,
        ),
      ),
    );
  }
}
