import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class LoadingOverlayWidget extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlayWidget({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Opacity(
            opacity: 0.6,
            child: ModalBarrier(
              dismissible: false,
              color: AppColors.navy.withValues(alpha: 0.4),
            ),
          ),
        if (isLoading)
          const Center(
            child: CircularProgressIndicator(color: AppColors.amber),
          ),
      ],
    );
  }
}
