// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/ceo_viewmodel.dart';
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
    // Start real-time listener on users/{uid}.status
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CeoViewModel>().watchCeoStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthViewModel, CeoViewModel>(
      builder: (context, authVM, ceoVM, child) {
        final user = authVM.user;

        // Auto-navigate when admin approves
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // Status icon
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

                  // Title
                  const Text(
                    'Application Under Review',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    'Your company registration has been submitted to the platform admin. '
                        'You will receive access as soon as verification is complete.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Info card
                  if (user != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.amber.shade200,
                        ),
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

                  // Loading indicator — waiting for admin
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
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Sign out
                  TextButton.icon(
                    onPressed: () async {
                      await authVM.signOut();
                      if (mounted) context.go(RouteNames.login);
                    },
                    icon: const Icon(Icons.logout, color: Colors.red, size: 18),
                    label: const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
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
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}