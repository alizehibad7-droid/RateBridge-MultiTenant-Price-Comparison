import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../utils/app_theme.dart';
import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/auth_widgets.dart';

class RegisterFieldUserView extends StatefulWidget {
  const RegisterFieldUserView({super.key});

  @override
  State<RegisterFieldUserView> createState() => _RegisterFieldUserViewState();
}

class _RegisterFieldUserViewState extends State<RegisterFieldUserView> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _inviteCodeController.dispose();
    super.dispose();
  }

  String? _required(String? v, [String label = 'This field']) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(v.trim())) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  String? _validateConfirmPassword(String? v) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  void _onInviteCodeChanged(String value) {
    _debounce?.cancel();
    final authVm = context.read<AuthViewModel>();

    if (value.trim().length < 4) {
      authVm.clearInviteValidation();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      authVm.validateInviteCode(value);
    });
  }

  Future<void> _submit(AuthViewModel authVm) async {
    if (!_formKey.currentState!.validate()) return;

    if (authVm.pendingInviteCompanyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid invite code from your CEO.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    authVm.clearError();
    await authVm.registerFieldUser(
      fullName: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      phone: _phoneController.text,
      inviteCode: _inviteCodeController.text,
    );

    if (!mounted) return;
    if (authVm.isRegistered) {
      context.go(RouteNames.fieldHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (authVm.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authVm.errorMessage!),
            backgroundColor: AppColors.danger,
          ),
        );
        authVm.clearError();
      }
    });

    final canSubmit = authVm.pendingInviteCompanyId != null &&
        !authVm.isValidatingInvite &&
        !authVm.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.roleSelection);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.fieldAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.group_outlined, color: AppColors.fieldAccent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Join Your Team', style: AppTextStyles.h2),
                          Text(
                            'Enter your CEO\'s invite code to get started.',
                            style: AppTextStyles.bodyMuted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ---- Invite code ----
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: appCardDecoration(
                    shadow: AppShadows.card,
                    borderColor: authVm.inviteError != null
                        ? AppColors.danger
                        : authVm.pendingInviteCompanyId != null
                            ? AppColors.success
                            : AppColors.border,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('COMPANY INVITE CODE', style: AppTextStyles.label),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _inviteCodeController,
                        textCapitalization: TextCapitalization.characters,
                        onChanged: _onInviteCodeChanged,
                        validator: (v) => _required(v, 'Invite code'),
                        style: AppTextStyles.body.copyWith(
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'RB-X7K2PQ',
                          prefixIcon: const Icon(Icons.key_outlined,
                              color: AppColors.textSecondary, size: 20),
                          suffixIcon: authVm.isValidatingInvite
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : authVm.pendingInviteCompanyId != null
                                  ? const Icon(Icons.check_circle, color: AppColors.success)
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (authVm.pendingInviteCompanyName != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.successBg,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.business, color: AppColors.success, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You\'ll join ${authVm.pendingInviteCompanyName}',
                                  style: const TextStyle(
                                    color: AppColors.success,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (authVm.inviteError != null)
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
                                  authVm.inviteError!,
                                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          'Ask your CEO or site manager for your company\'s invite code.',
                          style: AppTextStyles.bodyMuted,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ---- Personal info ----
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: appCardDecoration(shadow: AppShadows.card),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Your Information', style: AppTextStyles.h3),
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'FULL NAME',
                        controller: _nameController,
                        prefixIcon: Icons.person_outline,
                        placeholder: 'Ali Raza',
                        validator: (v) => _required(v, 'Full name'),
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'EMAIL ADDRESS',
                        controller: _emailController,
                        prefixIcon: Icons.email_outlined,
                        placeholder: 'you@example.com',
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
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'CONFIRM PASSWORD',
                        controller: _confirmPasswordController,
                        prefixIcon: Icons.lock_outline,
                        placeholder: '••••••••',
                        obscureText: true,
                        validator: _validateConfirmPassword,
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'PHONE NUMBER',
                        controller: _phoneController,
                        prefixIcon: Icons.phone_outlined,
                        placeholder: '+92 300 0000000',
                        keyboardType: TextInputType.phone,
                        validator: (v) => _required(v, 'Phone number'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AuthPrimaryButton(
                  label: 'Create Account',
                  isLoading: authVm.isLoading,
                  color: AppColors.fieldAccent,
                  onPressed: canSubmit ? () => _submit(authVm) : null,
                ),
                const SizedBox(height: 10),
                Text(
                  'Your account will be reviewed by your CEO before you can sign in.',
                  style: AppTextStyles.bodyMuted,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const AuthFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
