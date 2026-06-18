import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../utils/app_theme.dart';
import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/auth_widgets.dart';

class RegisterCeoView extends StatefulWidget {
  const RegisterCeoView({super.key});

  @override
  State<RegisterCeoView> createState() => _RegisterCeoViewState();
}

class _RegisterCeoViewState extends State<RegisterCeoView> {
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  int _step = 0;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();

  final _companyNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _companyPhoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _companyNameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _companyPhoneController.dispose();
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

  void _goToStep2() {
    if (_step1Key.currentState!.validate()) {
      setState(() => _step = 1);
    }
  }

  void _goToStep1() {
    setState(() => _step = 0);
  }

  Future<void> _submit(AuthViewModel authVm) async {
    if (!_step2Key.currentState!.validate()) return;
    authVm.clearError();

    await authVm.registerCEO(
      fullName: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      phone: _phoneController.text,
      companyName: _companyNameController.text,
      city: _cityController.text,
      address: _addressController.text,
    );

    if (!mounted) return;
    if (authVm.isRegistered) {
      context.go(RouteNames.ceoPending);
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: BackButton(
          onPressed: () {
            if (_step == 1) {
              _goToStep1();
            } else {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(RouteNames.roleSelection);
              }
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            children: [
              // Use conditional rendering instead of PageView with fixed height
              if (_step == 0) _buildStep1() else _buildStep2(authVm),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AuthFooter(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Form(
        key: _step1Key,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: appCardDecoration(shadow: AppShadows.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Personal Information', style: AppTextStyles.h2),
                        const SizedBox(height: 4),
                        Text('Tell us who you are to begin your journey.',
                            style: AppTextStyles.bodyMuted),
                      ],
                    ),
                  ),
                  const StepBadge(label: 'Step 1 of 2'),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  value: 0.5,
                  minHeight: 4,
                  color: AppColors.primary,
                  backgroundColor: AppColors.border,
                ),
              ),
              const SizedBox(height: 24),
              AuthTextField(
                label: 'FULL NAME',
                controller: _nameController,
                prefixIcon: Icons.person_outline,
                placeholder: 'John Doe',
                validator: (v) => _required(v, 'Full name'),
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'EMAIL ADDRESS',
                controller: _emailController,
                prefixIcon: Icons.email_outlined,
                placeholder: 'ceo@company.com',
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
              const SizedBox(height: 24),
              AuthPrimaryButton(label: 'Next Step', onPressed: _goToStep2),
              const SizedBox(height: 20),
              const TrustInfoRow(
                icon: Icons.shield_outlined,
                title: 'Data Security',
                subtitle:
                    'Your corporate data is encrypted with enterprise-grade standards.',
              ),
              const TrustInfoRow(
                icon: Icons.speed_outlined,
                title: 'Instant Setup',
                subtitle: 'Get your dashboard ready in less than 2 minutes.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep2(AuthViewModel authVm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Form(
        key: _step2Key,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: appCardDecoration(shadow: AppShadows.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Company Information', style: AppTextStyles.h2),
                        const SizedBox(height: 4),
                        Text('Tell us about the company you represent.',
                            style: AppTextStyles.bodyMuted),
                      ],
                    ),
                  ),
                  const StepBadge(label: 'Step 2 of 2'),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  value: 1.0,
                  minHeight: 4,
                  color: AppColors.primary,
                  backgroundColor: AppColors.border,
                ),
              ),
              const SizedBox(height: 24),
              AuthTextField(
                label: 'COMPANY NAME',
                controller: _companyNameController,
                prefixIcon: Icons.business_outlined,
                placeholder: 'Usman Associates',
                validator: (v) => _required(v, 'Company name'),
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'CITY',
                controller: _cityController,
                prefixIcon: Icons.location_city_outlined,
                placeholder: 'Rawalpindi',
                validator: (v) => _required(v, 'City'),
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'BUSINESS ADDRESS',
                controller: _addressController,
                prefixIcon: Icons.location_on_outlined,
                placeholder: 'Full address',
                validator: (v) => _required(v, 'Business address'),
              ),
              const SizedBox(height: 16),
              AuthTextField(
                label: 'PHONE NUMBER',
                controller: _companyPhoneController,
                prefixIcon: Icons.phone_outlined,
                placeholder: '+92 300 0000000',
                keyboardType: TextInputType.phone,
                validator: (v) => _required(v, 'Phone number'),
              ),
              const SizedBox(height: 24),
              AuthPrimaryButton(
                label: 'Submit Application',
                isLoading: authVm.isLoading,
                onPressed: () => _submit(authVm),
              ),
              const SizedBox(height: 10),
              Text(
                'Your profile will be reviewed by admins within 24 hours.',
                style: AppTextStyles.bodyMuted,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
