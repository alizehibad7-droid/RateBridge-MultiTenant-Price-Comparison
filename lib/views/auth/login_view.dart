import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    
    // Dismiss keyboard on submit
    FocusScope.of(context).unfocus();
    
    authVm.clearError();
    final success = await authVm.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;
    if (success && authVm.isAuthenticated) {
      _routeAfterLogin(authVm);
    }
  }

  void _routeAfterLogin(AuthViewModel authVm) {
    final role = authVm.role
        ?.toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('_', '');
    final status = authVm.user?.status?.toLowerCase();

    // Platform detection
    final bool isWeb = kIsWeb;
    final bool isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    bool isAllowed = false;

    // Platform + Role Access Control
    if (role == 'admin' || role == 'administrator') {
      // Admin -> Web Only
      if (isWeb) {
        isAllowed = true;
      }
    } else if (role == 'ceo' || role == 'supplier' || role == 'fielduser') {
      // CEO / Supplier / Field User -> Android Only
      if (isAndroid) {
        isAllowed = true;
      }
    } else {
      // No role or unknown role
      if (mounted) {
        context.push(RouteNames.roleSelection);
      }
      return;
    }

    if (!isAllowed) {
      if (mounted) {
        context.go(RouteNames.platformBlocked);
      }
      return;
    }

    if (!mounted) return;

    // Navigation for authorized users based on role and status
    switch (role) {
      case 'admin':
      case 'administrator':
        context.go(RouteNames.adminDashboard);
        break;
      case 'ceo':
        context.go(
          status == 'active' ? RouteNames.ceoDashboard : RouteNames.ceoPending,
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
            break;
          default:
            context.go(RouteNames.pendingApproval);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.screenBg,
        resizeToAvoidBottomInset: true,
        body: DecoratedBox(
          decoration: BoxDecoration(
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 10),
                          // Brand Logo
                          Container(
                            width: 70,
                            height: 70,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.navy,
                            ),
                            child: const Icon(
                              Icons.construction,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'RateBridge',
                            textAlign: TextAlign.center,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.navy,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Login Card
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: size.width < 400 ? 20 : 30,
                              vertical: 32,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.navy.withValues(alpha: 0.08),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
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
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Sign in to your account',
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Text(
                                    'Email Address',
                                    style: textTheme.labelLarge?.copyWith(
                                      color: AppColors.navy,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    validator: _validateEmail,
                                    decoration: const InputDecoration(
                                      hintText: 'name@company.com',
                                      prefixIcon: Icon(Icons.email_outlined),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Password',
                                    style: textTheme.labelLarge?.copyWith(
                                      color: AppColors.navy,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(authVm),
                                    validator: _validatePassword,
                                    decoration: InputDecoration(
                                      hintText: 'Enter password',
                                      prefixIcon: const Icon(Icons.lock_outlined),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                        onPressed: () => setState(
                                            () => _obscurePassword = !_obscurePassword),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () =>
                                          context.push(RouteNames.forgotPassword),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(50, 30),
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      margin: const EdgeInsets.only(bottom: 20),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: AppColors.error.withValues(alpha: 0.2)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.error_outline,
                                              color: AppColors.error, size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              authVm.errorMessage!,
                                              style: textTheme.bodySmall?.copyWith(
                                                color: AppColors.error,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  AuthPrimaryButton(
                                    label: 'SIGN IN',
                                    isLoading: authVm.isLoading,
                                    onPressed: () => _submit(authVm),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    children: [
                                      const Expanded(child: Divider()),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Text(
                                          'NEW TO RATEBRIDGE?',
                                          style: textTheme.labelSmall?.copyWith(
                                            letterSpacing: 1,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      const Expanded(child: Divider()),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  OutlinedButton(
                                    onPressed: () =>
                                        context.push(RouteNames.roleSelection),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'CREATE ACCOUNT',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700, letterSpacing: 1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Trust Badges
                          const Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 24,
                            runSpacing: 12,
                            children: [
                              _TrustBadge(
                                icon: Icons.lock_outline,
                                label: 'Secure Login',
                              ),
                              _TrustBadge(
                                icon: Icons.verified_user_outlined,
                                label: 'Verified Access',
                              ),
                              _TrustBadge(
                                icon: Icons.business_outlined,
                                label: 'B2B Pakistan',
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
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
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
