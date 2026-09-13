import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../theme/field_theme.dart';

class FieldMaterialGridSkeleton extends StatelessWidget {
  final int itemCount;

  const FieldMaterialGridSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(FieldSpacing.lg),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: FieldSpacing.md,
        crossAxisSpacing: FieldSpacing.md,
        childAspectRatio: 0.82,
      ),
      itemCount: itemCount,
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: FieldColors.borderSubtle,
      highlightColor: FieldColors.surfaceWhite,
      child: Container(
        decoration: FieldTheme.cardDecoration(),
        padding: const EdgeInsets.all(FieldSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: FieldColors.borderSubtle,
                shape: BoxShape.circle,
              ),
            ),
            const Spacer(),
            Container(
              height: 14,
              width: double.infinity,
              decoration: BoxDecoration(
                color: FieldColors.borderSubtle,
                borderRadius: BorderRadius.circular(FieldSpacing.xs),
              ),
            ),
            const SizedBox(height: FieldSpacing.sm),
            Container(
              height: 12,
              width: 100,
              decoration: BoxDecoration(
                color: FieldColors.borderSubtle,
                borderRadius: BorderRadius.circular(FieldSpacing.xs),
              ),
            ),
            const SizedBox(height: FieldSpacing.sm),
            Container(
              height: 14,
              width: 72,
              decoration: BoxDecoration(
                color: FieldColors.borderSubtle,
                borderRadius: BorderRadius.circular(FieldSpacing.xs),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
