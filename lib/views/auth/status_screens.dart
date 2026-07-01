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
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hourglass_empty_rounded, size: 80, color: AppColors.warning),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.read<AuthViewModel>().signOut(),
                child: const Text("Log Out"),
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
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block_flipped, size: 80, color: AppColors.error),
            const SizedBox(height: 24),
            const Text(
              "Account Suspended",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              "Your account has been suspended by an administrator. Please contact support for more information.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.read<AuthViewModel>().signOut(),
                child: const Text("Log Out"),
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
    final user = context.watch<AuthViewModel>().user;
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cancel_outlined, size: 80, color: AppColors.error),
            const SizedBox(height: 24),
            const Text(
              "Account Rejected",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "Your account application was rejected. ${user?.rejectionReason != null ? '\n\nReason: ${user?.rejectionReason}' : ''}",
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.read<AuthViewModel>().signOut(),
                child: const Text("Log Out"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
