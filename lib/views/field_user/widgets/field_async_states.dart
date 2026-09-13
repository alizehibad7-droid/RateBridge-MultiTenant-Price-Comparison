import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../theme/field_theme.dart';

/// Themed loading spinner for field user screens.
class FieldLoadingState extends StatelessWidget {
  final String? message;

  const FieldLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FieldSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: FieldColors.primaryNavy,
              strokeWidth: 2.5,
            ),
            if (message != null) ...[
              const SizedBox(height: FieldSpacing.md),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: FieldTypography.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Icon + title + subtitle empty state.
class FieldEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const FieldEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FieldSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 44,
              color: FieldColors.textMuted.withValues(alpha: 0.75),
            ),
            const SizedBox(height: FieldSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: FieldTypography.titleMedium,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: FieldSpacing.sm),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: FieldTypography.bodyMedium,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: FieldSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state with retry button.
class FieldErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  const FieldErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Retry',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FieldSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: FieldColors.statusDanger,
            ),
            const SizedBox(height: FieldSpacing.md),
            Text(title, style: FieldTypography.titleMedium),
            const SizedBox(height: FieldSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: FieldTypography.bodyMedium,
            ),
            const SizedBox(height: FieldSpacing.lg),
            FilledButton(
              onPressed: onRetry,
              child: Text(retryLabel, style: FieldTypography.titleMedium),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer list placeholder for orders / notifications / chat threads.
class FieldListSkeleton extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const FieldListSkeleton({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 72,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        FieldSpacing.lg,
        FieldSpacing.md,
        FieldSpacing.lg,
        FieldSpacing.xxl,
      ),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: FieldSpacing.sm),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: FieldColors.borderSubtle,
        highlightColor: FieldColors.surfaceWhite,
        child: Container(
          height: itemHeight,
          decoration: BoxDecoration(
            color: FieldColors.borderSubtle,
            borderRadius: BorderRadius.circular(FieldRadius.card),
          ),
        ),
      ),
    );
  }
}

/// Chat thread message loading skeleton.
class FieldChatThreadSkeleton extends StatelessWidget {
  const FieldChatThreadSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(FieldSpacing.lg),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _bubble(width: 180, align: Alignment.centerLeft),
        const SizedBox(height: FieldSpacing.md),
        _bubble(width: 220, align: Alignment.centerRight),
        const SizedBox(height: FieldSpacing.md),
        _bubble(width: 140, align: Alignment.centerLeft),
        const SizedBox(height: FieldSpacing.md),
        _bubble(width: 200, align: Alignment.centerRight),
      ],
    );
  }

  Widget _bubble({required double width, required Alignment align}) {
    return Align(
      alignment: align,
      child: Shimmer.fromColors(
        baseColor: FieldColors.borderSubtle,
        highlightColor: FieldColors.surfaceWhite,
        child: Container(
          width: width,
          height: 44,
          decoration: BoxDecoration(
            color: FieldColors.borderSubtle,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
