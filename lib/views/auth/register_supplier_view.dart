// MVVM: View — no business logic

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../utils/app_theme.dart';
import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/auth_widgets.dart';

const _supplierAccent = AppColors.supplierAccent;

const List<String> _materialCategories = [
  'Cement',
  'Steel & Rebar',
  'Aggregates',
  'Bricks & Blocks',
  'Sand & Gravel',
  'Finishing Materials',
  'Plumbing & Pipes',
  'Electrical Supplies',
  'Paints & Coatings',
  'Timber & Wood',
];

const List<String> _businessTypes = [
  'Manufacturer',
  'Wholesaler',
  'Distributor',
  'Retailer',
];

class RegisterSupplierView extends StatefulWidget {
  const RegisterSupplierView({super.key});

  @override
  State<RegisterSupplierView> createState() => _RegisterSupplierViewState();
}

class _RegisterSupplierViewState extends State<RegisterSupplierView> {
  final _formKey = GlobalKey<FormState>();

  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _cnicController = TextEditingController();
  final _addressController = TextEditingController();
  final _yearsController = TextEditingController();

  String _businessType = _businessTypes.first;
  final Set<String> _selectedCategories = {};

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _cnicController.dispose();
    _addressController.dispose();
    _yearsController.dispose();
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

  String? _validateCnic(String? v) {
    if (v == null || v.trim().isEmpty) return 'CNIC is required';
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 13) return 'CNIC must be 13 digits';
    return null;
  }

  String? _validateYears(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    if (int.tryParse(v.trim()) == null) return 'Enter a number';
    return null;
  }

  Future<void> _submit(AuthViewModel authVm) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one material category'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    authVm.clearError();
    await authVm.registerSupplier(
      ownerName: _ownerNameController.text,
      businessName: _businessNameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      phone: _phoneController.text,
      city: _cityController.text,
      cnic: _cnicController.text,
      businessType: _businessType,
      businessAddress: _addressController.text,
      categories: _selectedCategories.toList(),
      yearsInBusiness: int.tryParse(_yearsController.text.trim()) ?? 0,
    );

    if (!mounted) return;
    if (authVm.isRegistered) {
      context.go(RouteNames.supplierPending);
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
                        color: _supplierAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.inventory_2_outlined,
                          color: _supplierAccent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Supplier Registration',
                              style: AppTextStyles.h2),
                          Text(
                            'Create your global vendor profile.',
                            style: AppTextStyles.bodyMuted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ---- Business details ----
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: appCardDecoration(shadow: AppShadows.card),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Business Details', style: AppTextStyles.h3),
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'BUSINESS NAME',
                        controller: _businessNameController,
                        prefixIcon: Icons.storefront_outlined,
                        placeholder: 'Skyline Building Materials',
                        validator: (v) => _required(v, 'Business name'),
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'OWNER / CONTACT NAME',
                        controller: _ownerNameController,
                        prefixIcon: Icons.person_outline,
                        placeholder: 'Ahmed Khan',
                        validator: (v) => _required(v, 'Owner name'),
                      ),
                      const SizedBox(height: 16),
                      Text('BUSINESS TYPE', style: AppTextStyles.label),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _businessType,
                        items: _businessTypes
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t, style: AppTextStyles.body),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _businessType = v ?? _businessType),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.category_outlined,
                              color: AppColors.textSecondary, size: 20),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'YEARS IN BUSINESS',
                        controller: _yearsController,
                        prefixIcon: Icons.timeline_outlined,
                        placeholder: '5',
                        keyboardType: TextInputType.number,
                        validator: _validateYears,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ---- Categories ----
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: appCardDecoration(shadow: AppShadows.card),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Material Categories', style: AppTextStyles.h3),
                      const SizedBox(height: 4),
                      Text(
                        'Select all categories you supply. You can update this later.',
                        style: AppTextStyles.bodyMuted,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _materialCategories.map((cat) {
                          final selected = _selectedCategories.contains(cat);
                          return GestureDetector(
                            onTap: () => setState(() {
                              if (selected) {
                                _selectedCategories.remove(cat);
                              } else {
                                _selectedCategories.add(cat);
                              }
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: selected
                                    ? _supplierAccent.withOpacity(0.12)
                                    : AppColors.surface,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                border: Border.all(
                                  color: selected
                                      ? _supplierAccent
                                      : AppColors.border,
                                  width: selected ? 1.2 : 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (selected) ...[
                                    const Icon(Icons.check,
                                        size: 14, color: _supplierAccent),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: selected
                                          ? _supplierAccent
                                          : AppColors.textSecondary,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ---- Contact & account ----
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: appCardDecoration(shadow: AppShadows.card),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Contact & Account', style: AppTextStyles.h3),
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'EMAIL ADDRESS',
                        controller: _emailController,
                        prefixIcon: Icons.email_outlined,
                        placeholder: 'sales@business.com',
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
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'CNIC',
                        controller: _cnicController,
                        prefixIcon: Icons.badge_outlined,
                        placeholder: '00000-0000000-0',
                        keyboardType: TextInputType.number,
                        validator: _validateCnic,
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'CITY',
                        controller: _cityController,
                        prefixIcon: Icons.location_city_outlined,
                        placeholder: 'Lahore',
                        validator: (v) => _required(v, 'City'),
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'BUSINESS ADDRESS',
                        controller: _addressController,
                        prefixIcon: Icons.location_on_outlined,
                        placeholder: 'Full warehouse / office address',
                        validator: (v) => _required(v, 'Business address'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AuthPrimaryButton(
                  label: 'Submit Application',
                  isLoading: authVm.isLoading,
                  color: _supplierAccent,
                  onPressed: () => _submit(authVm),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your profile will be reviewed by the RateBridge team within 24 hours.',
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
