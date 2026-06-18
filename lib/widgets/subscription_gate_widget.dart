import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/subscription_viewmodel.dart';
import '../models/subscription_model.dart';
import '../constants/route_names.dart';
import '../constants/app_colors.dart';

class SubscriptionGateWidget extends StatelessWidget {
  final Widget child;
  final String featureName;

  const SubscriptionGateWidget({
    required this.child,
    required this.featureName,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final companyId = authVm.user?.companyId ?? '';
    final isCeo = authVm.user?.role.toUpperCase() == 'CEO';

    if (companyId.isEmpty) return child;

    return StreamBuilder<SubscriptionModel?>(
      stream: context.read<SubscriptionViewModel>().watchSubscription(companyId),
      builder: (context, snapshot) {
        final sub = snapshot.data;
        // Feature is unlocked if AI is unlocked in the plan or if explicitly enabled on company doc
        final aiUnlocked = sub?.planDef.aiUnlocked ?? false;
        
        // If snapshot is still loading and we don't have data yet, show a loader or just the blurred child
        if (snapshot.connectionState == ConnectionState.waiting && sub == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (aiUnlocked) return child;

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // The blurred background content
              Opacity(
                opacity: 0.4,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: AbsorbPointer(child: child),
                ),
              ),
              
              // The Lock Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.sidebarBackground.withOpacity(0.4),
                        AppColors.background.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
                        ),
                        child: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 32),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        featureName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Premium Feature',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (isCeo)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              minimumSize: const Size(160, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => context.go(RouteNames.ceoSubscription),
                            child: const Text('Upgrade Now'),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          decoration: BoxDecoration(
                            color: AppColors.infoBg.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Please ask your CEO to upgrade the company plan to unlock this feature.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
