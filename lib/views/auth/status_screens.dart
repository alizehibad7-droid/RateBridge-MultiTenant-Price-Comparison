import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_viewmodel.dart';
import '../../constants/app_colors.dart';

class PendingApprovalView extends StatelessWidget {
  final String title;
  final String message;

  const PendingApprovalView({
    super.key,
    this.title = 'Account Pending Approval',
    this.message =
        'Your account is pending admin approval. Please wait until an administrator reviews your request.',
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.screenBg,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.hourglass_empty_rounded,
              size: 80,
              color: AppColors.amber,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.read<AuthViewModel>().signOut(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error, width: 1.5),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Log Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SuspendedView extends StatelessWidget {
  const SuspendedView({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.screenBg,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block_flipped, size: 80, color: AppColors.error),
            const SizedBox(height: 24),
            Text(
              'Account Suspended',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Your account has been suspended by an administrator. Please contact support for more information.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.read<AuthViewModel>().signOut(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error, width: 1.5),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Log Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RejectedView extends StatelessWidget {
  const RejectedView({super.key});

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final user = authVm.user;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.screenBg,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cancel_outlined, size: 80, color: AppColors.error),
            const SizedBox(height: 24),
            Text(
              'Account Rejected',
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Your account application was rejected. ${user?.rejectionReason != null ? '\n\nReason: ${user?.rejectionReason}' : ''}',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => authVm.signOut(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error, width: 1.5),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Log Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
