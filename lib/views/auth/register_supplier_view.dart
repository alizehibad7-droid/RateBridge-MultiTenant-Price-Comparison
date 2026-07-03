// MVVM: View — no business logic

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/pakistan_cities.dart';
import '../../constants/construction_categories_seed.dart';
import '../../constants/route_names.dart';
import '../../models/category_model.dart';
import '../../repositories/material_repository.dart';
import '../../utils/app_theme.dart';
import '../../utils/chat_image_utils.dart';
import '../../utils/pakistan_validators.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/auth_widgets.dart';

const _supplierAccent = AppColors.amber;
const _totalSteps = 3;

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
  final _cnicController = TextEditingController();
  final _addressController = TextEditingController();
  final _yearsController = TextEditingController();
  final _ntnController = TextEditingController();

  String _businessType = kSupplierLegalBusinessTypes.first;
  String? _selectedCity;
  final Set<String> _coverageAreas = {};
  final Set<String> _selectedCategories = {};

  Uint8List? _cnicFrontBytes;
  Uint8List? _cnicBackBytes;
  Uint8List? _shopPhotoBytes;
  Uint8List? _licenseBytes;
  Uint8List? _certificationBytes;

  int _currentStep = 0;
  bool _categoriesLoading = true;
  List<CategoryModel> _firestoreCategories = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  Future<void> _loadCategories() async {
    try {
      final categories =
          await context.read<MaterialRepository>().getCategories();
      if (!mounted) return;
      setState(() {
        _firestoreCategories = categories.isNotEmpty
            ? categories
            : kConstructionCategorySeeds
                .map((entry) => entry.toCategoryModel())
                .toList();
        _categoriesLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _firestoreCategories = kConstructionCategorySeeds
            .map((entry) => entry.toCategoryModel())
            .toList();
        _categoriesLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _cnicController.dispose();
    _addressController.dispose();
    _yearsController.dispose();
    _ntnController.dispose();
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

  String? _validateYears(String? v) {
    if (v == null || v.trim().isEmpty) return 'Years in business is required';
    final years = int.tryParse(v.trim());
    if (years == null || years < 0) return 'Enter a valid number';
    return null;
  }

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        if (!_formKey.currentState!.validate()) return false;
        if (_cnicFrontBytes == null || _cnicBackBytes == null) {
          _showError('CNIC front and back photos are required');
          return false;
        }
        return true;
      case 1:
        if (_selectedCity == null || _selectedCity!.isEmpty) {
          _showError('Please select your business city');
          return false;
        }
        if (_addressController.text.trim().isEmpty) {
          _showError('Business address is required');
          return false;
        }
        if (_coverageAreas.isEmpty) {
          _showError('Select at least one delivery coverage area');
          return false;
        }
        return true;
      case 2:
        if (_shopPhotoBytes == null &&
            _licenseBytes == null &&
            _certificationBytes == null) {
          _showError(
            'Upload at least one business proof (shop photo, license, or certification)',
          );
          return false;
        }
        if (_selectedCategories.isEmpty) {
          _showError('Select at least one material category you deal in');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  void _nextStep() {
    if (!_validateStep(_currentStep)) return;
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _pickImage(void Function(Uint8List?) setter) async {
    final source = await ChatImageUtils.showSourceSheet(context);
    if (source == null) return;
    final picked = await ChatImageUtils.pickImage(source);
    if (picked == null || !mounted) return;
    setState(() => setter(picked.bytes));
  }

  Future<void> _submit(AuthViewModel authVm) async {
    if (!_validateStep(0) || !_validateStep(1) || !_validateStep(2)) return;

    authVm.clearError();
    await authVm.registerSupplier(
      ownerName: _ownerNameController.text,
      businessName: _businessNameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      phone: _phoneController.text,
      city: _selectedCity!,
      cnic: _cnicController.text,
      businessType: _businessType,
      businessAddress: _addressController.text,
      categories: _selectedCategories.toList(),
      yearsInBusiness: int.parse(_yearsController.text.trim()),
      businessRegistrationNumber: _ntnController.text.trim().isEmpty
          ? null
          : _ntnController.text.trim(),
      deliveryCoverageAreas: _coverageAreas.toList(),
      cnicFrontBytes: _cnicFrontBytes!,
      cnicBackBytes: _cnicBackBytes!,
      shopPhotoBytes: _shopPhotoBytes,
      businessLicenseBytes: _licenseBytes,
      certificationBytes: _certificationBytes,
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
            if (_currentStep > 0) {
              _previousStep();
              return;
            }
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.roleSelection);
            }
          },
        ),
        title: Text('Step ${_currentStep + 1} of $_totalSteps'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / _totalSteps,
                backgroundColor: AppColors.border,
                color: _supplierAccent,
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 16),
                      if (_currentStep == 0) _buildStepOne(),
                      if (_currentStep == 1) _buildStepTwo(),
                      if (_currentStep == 2) _buildStepThree(),
                      const SizedBox(height: 20),
                      _buildNavigation(authVm),
                      const SizedBox(height: 16),
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
    final subtitles = [
      'Business identity and owner verification',
      'Where you operate and deliver',
      'Business proof and material categories',
    ];
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _supplierAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.storefront_outlined, color: _supplierAccent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Supplier Registration', style: AppTextStyles.h2),
              Text(subtitles[_currentStep], style: AppTextStyles.bodyMuted),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepOne() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionCard(
          title: 'Business Identity',
          children: [
            AuthTextField(
              label: 'BUSINESS / SHOP NAME',
              controller: _businessNameController,
              prefixIcon: Icons.storefront_outlined,
              placeholder: 'Skyline Building Materials',
              validator: (v) => _required(v, 'Business name'),
            ),
            const SizedBox(height: 16),
            Text('BUSINESS TYPE', style: AppTextStyles.label),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _businessType,
              items: kSupplierLegalBusinessTypes
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t, style: AppTextStyles.body),
                    ),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => _businessType = v ?? _businessType),
              decoration: const InputDecoration(
                prefixIcon: Icon(
                  Icons.business_center_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
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
            const SizedBox(height: 16),
            AuthTextField(
              label: 'NTN / BUSINESS REGISTRATION NO.',
              controller: _ntnController,
              prefixIcon: Icons.numbers_outlined,
              placeholder: 'Optional',
              helperText: 'Optional but improves approval chances',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Owner / Contact Identity',
          children: [
            AuthTextField(
              label: 'OWNER FULL NAME',
              controller: _ownerNameController,
              prefixIcon: Icons.person_outline,
              placeholder: 'Ahmed Khan',
              validator: (v) => _required(v, 'Owner name'),
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'CNIC NUMBER',
              controller: _cnicController,
              prefixIcon: Icons.badge_outlined,
              placeholder: '35202-1234567-1',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(13),
                _CnicInputFormatter(),
              ],
              validator: PakistanValidators.validateCnic,
            ),
            const SizedBox(height: 16),
            _imageUploadTile(
              label: 'CNIC Front Photo *',
              bytes: _cnicFrontBytes,
              onPick: () => _pickImage((b) => _cnicFrontBytes = b),
              onClear: () => setState(() => _cnicFrontBytes = null),
            ),
            const SizedBox(height: 12),
            _imageUploadTile(
              label: 'CNIC Back Photo *',
              bytes: _cnicBackBytes,
              onPick: () => _pickImage((b) => _cnicBackBytes = b),
              onClear: () => setState(() => _cnicBackBytes = null),
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
          ],
        ),
      ],
    );
  }

  Widget _buildStepTwo() {
    return _sectionCard(
      title: 'Business Location',
      children: [
        Text('CITY', style: AppTextStyles.label),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCity,
          hint: Text('Select city', style: AppTextStyles.bodyMuted),
          isExpanded: true,
          items: kPakistanMajorCities
              .map(
                (city) => DropdownMenuItem(
                  value: city,
                  child: Text(city, style: AppTextStyles.body),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedCity = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(
              Icons.location_city_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: 'FULL BUSINESS ADDRESS',
          controller: _addressController,
          prefixIcon: Icons.location_on_outlined,
          placeholder: 'Warehouse / shop address with landmark',
          validator: (v) => _required(v, 'Business address'),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        Text('DELIVERY COVERAGE AREAS', style: AppTextStyles.label),
        const SizedBox(height: 4),
        Text(
          'Select all cities/areas you can deliver to.',
          style: AppTextStyles.bodyMuted,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kPakistanMajorCities.map((city) {
            final selected = _coverageAreas.contains(city);
            return FilterChip(
              label: Text(city),
              selected: selected,
              selectedColor: _supplierAccent.withValues(alpha: 0.15),
              checkmarkColor: _supplierAccent,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    _coverageAreas.add(city);
                  } else {
                    _coverageAreas.remove(city);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStepThree() {
    final categoryNames = _firestoreCategories.isNotEmpty
        ? _firestoreCategories.map((c) => c.name).toList()
        : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionCard(
          title: 'Business Proof',
          subtitle: 'Upload at least one document for verification.',
          children: [
            _imageUploadTile(
              label: 'Shop / Warehouse Photo',
              bytes: _shopPhotoBytes,
              onPick: () => _pickImage((b) => _shopPhotoBytes = b),
              onClear: () => setState(() => _shopPhotoBytes = null),
            ),
            const SizedBox(height: 12),
            _imageUploadTile(
              label: 'Business / Trade License (optional)',
              bytes: _licenseBytes,
              onPick: () => _pickImage((b) => _licenseBytes = b),
              onClear: () => setState(() => _licenseBytes = null),
            ),
            const SizedBox(height: 12),
            _imageUploadTile(
              label: 'Additional Certification (optional)',
              bytes: _certificationBytes,
              onPick: () => _pickImage((b) => _certificationBytes = b),
              onClear: () => setState(() => _certificationBytes = null),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Material Categories',
          subtitle:
              'Declare what you supply. You will add actual listings from your dashboard later.',
          children: [
            if (_categoriesLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (categoryNames.isEmpty)
              Text(
                'Categories are loading from the platform catalog. Pull back after signing in if empty.',
                style: AppTextStyles.bodyMuted,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categoryNames.map((cat) {
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
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? _supplierAccent.withValues(alpha: 0.12)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: selected ? _supplierAccent : AppColors.border,
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
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w400,
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
      ],
    );
  }

  Widget _buildNavigation(AuthViewModel authVm) {
    final isLast = _currentStep == _totalSteps - 1;
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: authVm.isLoading ? null : _previousStep,
              child: const Text('Back'),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: AuthPrimaryButton(
            label: isLast ? 'Submit Application' : 'Next',
            isLoading: authVm.isLoading,
            color: _supplierAccent,
            onPressed: authVm.isLoading
                ? null
                : () {
                    if (isLast) {
                      _submit(authVm);
                    } else {
                      _nextStep();
                    }
                  },
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: appCardDecoration(shadow: AppShadows.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTextStyles.h3),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: AppTextStyles.bodyMuted),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _imageUploadTile({
    required String label,
    required Uint8List? bytes,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: bytes == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                          color: AppColors.textSecondary.withValues(alpha: 0.7)),
                      const SizedBox(height: 6),
                      Text('Tap to upload', style: AppTextStyles.bodyMuted),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.memory(bytes, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black54,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(32, 32),
                          ),
                          onPressed: onClear,
                          icon: const Icon(Icons.close, size: 16),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = PakistanValidators.formatCnic(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
