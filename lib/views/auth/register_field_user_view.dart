import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/field_user_registration_options.dart';
import '../../constants/route_names.dart';
import '../../utils/pakistan_validators.dart';
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
  final _cnicController = TextEditingController();
  final _otherJobTitleController = TextEditingController();
  final _assignedSiteController = TextEditingController();
  final _inviteCodeController = TextEditingController();

  String _jobTitle = kFieldUserJobTitles.first;

  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _cnicController.dispose();
    _otherJobTitleController.dispose();
    _assignedSiteController.dispose();
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

  String? _validateJobTitleOther(String? v) {
    if (_jobTitle != kFieldUserJobTitleOther) return null;
    if (v == null || v.trim().isEmpty) {
      return 'Please specify your job title';
    }
    return null;
  }

  String _resolvedJobTitle() {
    if (_jobTitle == kFieldUserJobTitleOther) {
      return _otherJobTitleController.text.trim();
    }
    return _jobTitle;
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
          backgroundColor: AppColors.error,
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
      cnicNumber: _cnicController.text,
      jobTitle: _resolvedJobTitle(),
      assignedSite: _assignedSiteController.text,
    );

    if (!mounted) return;
    if (authVm.isRegistered) {
      context.go(RouteNames.fieldHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final textTheme = Theme.of(context).textTheme;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (authVm.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authVm.errorMessage!),
            backgroundColor: AppColors.error,
          ),
        );
        authVm.clearError();
      }
    });

    final canSubmit = authVm.pendingInviteCompanyId != null &&
        !authVm.isValidatingInvite &&
        !authVm.isLoading;

    return Scaffold(
      backgroundColor: AppColors.screenBg,
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
        title: const Text('Step 1 of 1'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: LinearProgressIndicator(
                value: 1.0,
                backgroundColor: AppColors.border,
                color: AppColors.amber,
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),

                // ---- Invite code ----
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: authVm.inviteError != null
                          ? AppColors.error
                          : authVm.pendingInviteCompanyId != null
                              ? AppColors.success
                              : AppColors.border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('COMPANY INVITE CODE', style: textTheme.labelLarge?.copyWith(color: AppColors.navy)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _inviteCodeController,
                        textCapitalization: TextCapitalization.characters,
                        onChanged: _onInviteCodeChanged,
                        validator: (v) => _required(v, 'Invite code'),
                        style: textTheme.bodyLarge?.copyWith(
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'RB-X7K2PQ',
                          prefixIcon: const Icon(Icons.key_outlined, size: 20),
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
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.business, color: AppColors.success, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You\'ll join ${authVm.pendingInviteCompanyName}',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppColors.success,
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
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authVm.inviteError!,
                                  style: textTheme.bodySmall?.copyWith(color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          'Ask your CEO or site manager for your company\'s invite code.',
                          style: textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ---- Personal identity ----
                _sectionCard(
                  title: 'Personal Identity',
                  subtitle: 'Details used for your company employee record.',
                  children: [
                    AuthTextField(
                      label: 'FULL NAME',
                      controller: _nameController,
                      prefixIcon: Icons.person_outline,
                      placeholder: 'Ali Raza',
                      validator: (v) => _required(v, 'Full name'),
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      label: 'PHONE NUMBER',
                      controller: _phoneController,
                      prefixIcon: Icons.phone_outlined,
                      placeholder: '0300 1234567',
                      keyboardType: TextInputType.phone,
                      validator: PakistanValidators.validatePhone,
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
                      label: 'CNIC NUMBER',
                      controller: _cnicController,
                      prefixIcon: Icons.badge_outlined,
                      placeholder: '35202-1234567-1',
                      keyboardType: TextInputType.number,
                      inputFormatters: [CnicTextInputFormatter()],
                      validator: PakistanValidators.validateCnic,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ---- Role information ----
                _sectionCard(
                  title: 'Role Information',
                  subtitle: 'How you work on site for this company.',
                  children: [
                    Text('JOB TITLE / DESIGNATION', style: textTheme.labelLarge?.copyWith(color: AppColors.navy)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _jobTitle,
                      isExpanded: true,
                      items: kFieldUserJobTitles
                          .map(
                            (title) => DropdownMenuItem(
                              value: title,
                              child: Text(title, style: textTheme.bodyLarge),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(
                        () => _jobTitle = v ?? kFieldUserJobTitles.first,
                      ),
                    ),
                    if (_jobTitle == kFieldUserJobTitleOther) ...[
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'SPECIFY JOB TITLE',
                        controller: _otherJobTitleController,
                        prefixIcon: Icons.edit_outlined,
                        placeholder: 'e.g. Quantity Surveyor',
                        validator: _validateJobTitleOther,
                      ),
                    ],
                    const SizedBox(height: 16),
                    AuthTextField(
                      label: 'ASSIGNED SITE / LOCATION',
                      controller: _assignedSiteController,
                      prefixIcon: Icons.place_outlined,
                      placeholder: 'Site B - DHA Phase 6',
                      validator: (v) => _required(v, 'Assigned site'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                AuthPrimaryButton(
                  label: 'Create Account',
                  isLoading: authVm.isLoading,
                  onPressed: canSubmit ? () => _submit(authVm) : null,
                ),
                const SizedBox(height: 10),
                Text(
                  'Your account is active immediately — you can start ordering materials right away.',
                  style: textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const AuthFooter(),
              ],
            ),
          ),
        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.group_outlined, color: AppColors.amber),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Join Your Team', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.navy)),
              Text(
                'Enter your CEO\'s invite code to get started.',
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.navy)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
