// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';
import 'package:intl/intl.dart';

class SupplierPendingView extends StatelessWidget {
  const SupplierPendingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SupplierViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.status == 'active') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go(RouteNames.supplierDashboard);
          });
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Padding(
            padding: const EdgeInsets.all(32.0),
            child: viewModel.status == 'rejected'
                ? _buildRejectedState(context, viewModel)
                : _buildPendingState(context, viewModel),
          ),
        );
      },
    );
  }

  Widget _buildPendingState(BuildContext context, SupplierViewModel viewModel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.access_time_filled_rounded, size: 80, color: Colors.amber),
        const SizedBox(height: 24),
        const Text(
          'Account Under Review',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text(
          'Your supplier registration is being reviewed by our compliance team. Verification usually takes 24-48 hours.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
        ),
        const SizedBox(height: 32),
        if (viewModel.profile != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('Submitted: ${DateFormat('MMM dd, yyyy').format(viewModel.profile!.createdAt)}',
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => viewModel.loadProfile(), // Logic for signout is usually in AuthVM
            child: const Text('Refresh Status'),
          ),
        ),
        TextButton(
          onPressed: () {
            // Access AuthViewModel to sign out
          },
          child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
        ),
      ],
    );
  }

  Widget _buildRejectedState(BuildContext context, SupplierViewModel viewModel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.cancel_rounded, size: 80, color: AppColors.error),
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
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('REASON:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 12)),
              const SizedBox(height: 4),
              Text(viewModel.rejectionReason ?? 'Information provided was insufficient for verification.',
                  style: const TextStyle(color: AppColors.error)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => context.push(RouteNames.supplierAppeal),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
          child: const Text('SUBMIT APPEAL'),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {}, // Auth Sign Out
          child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
        ),
      ],
    );
  }
}
