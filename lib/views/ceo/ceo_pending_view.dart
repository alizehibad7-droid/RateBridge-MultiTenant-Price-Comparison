// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../models/user_model.dart';
import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';
import 'package:intl/intl.dart';

class CeoPendingView extends StatefulWidget {
  const CeoPendingView({super.key});

  @override
  State<CeoPendingView> createState() => _CeoPendingViewState();
}

class _CeoPendingViewState extends State<CeoPendingView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CeoViewModel>().watchCeoStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthViewModel, CeoViewModel>(
      builder: (context, authVM, ceoVM, child) {
        final user = authVM.user;

        if (user?.status == 'active') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go(RouteNames.ceoDashboard);
          });
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: user?.status == 'rejected'
                  ? _buildRejectedState(context, authVM, user!)
                  : _buildPendingState(context, authVM, user),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingState(
    BuildContext context,
    AuthViewModel authVM,
    UserModel? user,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.hourglass_empty_rounded,
            size: 56,
            color: Colors.amber,
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'Application Under Review',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Your company registration is under review.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 15,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        if (user != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Status: Pending Admin Approval',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _infoRow('Name', user.name),
                _infoRow('Email', user.email),
                _infoRow(
                  'Submitted',
                  DateFormat('MMM dd, yyyy').format(user.createdAt),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Waiting for admin review...',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
        const Spacer(),
        _signOutButton(context, authVM),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRejectedState(
    BuildContext context,
    AuthViewModel authVM,
    UserModel user,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        const Icon(Icons.cancel_rounded, size: 80, color: AppColors.danger),
        const SizedBox(height: 24),
        const Text(
          'Registration Rejected',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.dangerBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'REASON:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.danger,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.rejectionReason ??
                    'Information provided was insufficient for verification.',
                style: const TextStyle(color: AppColors.danger),
              ),
            ],
          ),
        ),
        const Spacer(),
        _signOutButton(context, authVM),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _signOutButton(BuildContext context, AuthViewModel authVM) {
    return TextButton.icon(
      onPressed: () async {
        await authVM.signOut();
        if (context.mounted) context.go(RouteNames.login);
      },
      icon: const Icon(Icons.logout, color: Colors.red, size: 18),
      label: const Text(
        'Sign Out',
        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
