import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../theme/field_theme.dart';

class FieldChatListSkeleton extends StatelessWidget {
  const FieldChatListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        FieldSpacing.lg,
        FieldSpacing.sm,
        FieldSpacing.lg,
        FieldSpacing.xxl,
      ),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: FieldSpacing.sm),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: FieldColors.borderSubtle,
        highlightColor: FieldColors.surfaceWhite,
        child: Container(
          height: 76,
          padding: const EdgeInsets.all(FieldSpacing.md),
          decoration: BoxDecoration(
            color: FieldColors.borderSubtle,
            borderRadius: BorderRadius.circular(FieldRadius.card),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: FieldColors.surfaceWhite,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: FieldSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 12,
                      width: 120,
                      color: FieldColors.surfaceWhite,
                    ),
                    const SizedBox(height: FieldSpacing.sm),
                    Container(
                      height: 10,
                      width: double.infinity,
                      color: FieldColors.surfaceWhite,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
