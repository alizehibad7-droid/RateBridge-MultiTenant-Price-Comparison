import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';
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
  bool _obscurePassword = true;

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
    final success = await authVm.signIn(
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;
    if (success && authVm.isAuthenticated) {
      _routeAfterLogin(authVm);
    }
  }

  void _routeAfterLogin(AuthViewModel authVm) {
    final role =
        authVm.role?.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    final status = authVm.user?.status?.toLowerCase();

    switch (role) {
      case 'admin':
        context.go(RouteNames.adminDashboard);
        break;
      case 'ceo':
        context.go(
          status == 'active'
              ? RouteNames.ceoDashboard
              : RouteNames.ceoPending,
        );
        break;
      case 'supplier':
        context.go(
          status == 'active'
              ? RouteNames.supplierDashboard
              : RouteNames.supplierPending,
        );
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
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: AppColors.screenBg,
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.screenBg,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.navy.withValues(alpha: 0.07),
              AppColors.screenBg,
            ],
            stops: const [0.0, 0.42],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.navy,
                      ),
                      child: const Icon(
                        Icons.construction,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'RateBridge',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(30, 32, 30, 28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.navy.withValues(alpha: 0.08),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Welcome back',
                              textAlign: TextAlign.center,
                              style: textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Sign in to your account',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'Email Address',
                              style: textTheme.labelLarge?.copyWith(
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                              style: textTheme.bodyLarge,
                              decoration: const InputDecoration(
                                hintText: 'Enter your email',
                                prefixIcon: Icon(Icons.email_outlined, size: 20),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Password',
                              style: textTheme.labelLarge?.copyWith(
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              validator: _validatePassword,
                              style: textTheme.bodyLarge,
                              decoration: InputDecoration(
                                hintText: 'Enter your password',
                                prefixIcon: const Icon(Icons.lock_outlined, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () =>
                                    context.push(RouteNames.forgotPassword),
                                child: Text(
                                  'Forgot Password?',
                                  style: textTheme.labelLarge?.copyWith(
                                    color: AppColors.amber,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (authVm.errorMessage != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: AppColors.error,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        authVm.errorMessage!,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            AuthPrimaryButton(
                              label: 'Sign In',
                              isLoading: authVm.isLoading,
                              onPressed: () => _submit(authVm),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: Text(
                                    'or',
                                    style: textTheme.labelSmall,
                                  ),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              "Don't have an account?",
                              textAlign: TextAlign.center,
                              style: textTheme.labelSmall,
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () =>
                                  context.push(RouteNames.roleSelection),
                              child: const Text('Create Account'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        _TrustBadge(
                          icon: Icons.lock_outline,
                          label: 'Secure Login',
                        ),
                        _TrustBadge(
                          icon: Icons.verified_outlined,
                          label: 'Verified Platform',
                        ),
                        _TrustBadge(
                          icon: Icons.construction_outlined,
                          label: 'B2B Only',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TrustBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
        ),
      ],
    );
  }
}
