import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../utils/app_theme.dart';
import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/auth_widgets.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    return null;
  }

  Future<void> _submit(AuthViewModel authVm) async {
    if (!_formKey.currentState!.validate()) return;
    authVm.clearError();
    final success = await authVm.signIn(_emailController.text, _passwordController.text);

    if (!mounted) return;
    if (success && authVm.isAuthenticated) {
      _routeAfterLogin(authVm);
    }
  }

  void _routeAfterLogin(AuthViewModel authVm) {
    // Normalize role string to handle variations like 'field_user' vs 'fielduser'
    final role = authVm.role?.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    final status = authVm.user?.status?.toLowerCase();

    switch (role) {
      case 'admin':
        context.go(RouteNames.adminDashboard);
        break;
      case 'ceo':
        context.go(status == 'active' ? RouteNames.ceoDashboard : RouteNames.ceoPending);
        break;
      case 'supplier':
        context.go(status == 'active' ? RouteNames.supplierDashboard : RouteNames.supplierPending);
        break;
      case 'fielduser':
        switch (status) {
          case 'active':
            context.go(RouteNames.fieldHome);
            break;
          case 'rejected':
            context.go(RouteNames.rejected);
            break;
          case 'suspended':
            context.go(RouteNames.suspended);
          default:
            context.go(RouteNames.pendingApproval);
        }
        break;
      default:
        context.go(RouteNames.roleSelection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.architecture, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Welcome back', style: AppTextStyles.h1, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                  'Sign in to continue managing your procurement.',
                  style: AppTextStyles.bodyMuted,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: appCardDecoration(shadow: AppShadows.card),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AuthTextField(
                        label: 'EMAIL ADDRESS',
                        controller: _emailController,
                        prefixIcon: Icons.email_outlined,
                        placeholder: 'you@company.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'PASSWORD',
                        controller: _passwordController,
                        prefixIcon: Icons.lock_outline,
                        placeholder: '••••••••',
                        obscureText: true,
                        validator: _validatePassword,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push(RouteNames.forgotPassword),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (authVm.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.dangerBg,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authVm.errorMessage!,
                                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      AuthPrimaryButton(
                        label: 'Sign In',
                        isLoading: authVm.isLoading,
                        onPressed: () => _submit(authVm),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account?", style: AppTextStyles.bodyMuted),
                    TextButton(
                      onPressed: () => context.push(RouteNames.roleSelection),
                      child: const Text('Create one'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const AuthFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
