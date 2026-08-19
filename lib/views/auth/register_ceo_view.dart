import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/ceo_registration_options.dart';
import '../../constants/pakistan_cities.dart';
import '../../constants/route_names.dart';
import '../../utils/app_theme.dart';
import '../../utils/chat_image_utils.dart';
import '../../utils/pakistan_validators.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/auth_widgets.dart';

const _totalSteps = 3;

class RegisterCeoView extends StatefulWidget {
  const RegisterCeoView({super.key});

  @override
  State<RegisterCeoView> createState() => _RegisterCeoViewState();
}

class _RegisterCeoViewState extends State<RegisterCeoView> {
  final _formKey = GlobalKey<FormState>();

  final _companyNameController = TextEditingController();
  final _yearsController = TextEditingController();
  final _ntnController = TextEditingController();
  final _nameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _activeSitesController = TextEditingController();

  String _companyType = kCompanyTypes.first;
  String _designation = kCeoDesignations.first;
  String? _selectedCity;
  String? _estimatedVolume;

  Uint8List? _cnicFrontBytes;
  Uint8List? _cnicBackBytes;
  Uint8List? _registrationCertBytes;
  Uint8List? _officePhotoBytes;

  int _currentStep = 0;

  @override
  void dispose() {
    _companyNameController.dispose();
    _yearsController.dispose();
    _ntnController.dispose();
    _nameController.dispose();
    _cnicController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _activeSitesController.dispose();
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
    if (v == null || v.trim().isEmpty) return 'Years in operation is required';
    final years = int.tryParse(v.trim());
    if (years == null || years < 0) return 'Enter a valid number';
    return null;
  }

  String? _validateActiveSites(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'Number of active sites is required';
    }
    final count = int.tryParse(v.trim());
    if (count == null || count < 0) return 'Enter a valid number';
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
          _showError('Please select your company city');
          return false;
        }
        if (_addressController.text.trim().isEmpty) {
          _showError('Company address is required');
          return false;
        }
        if (_estimatedVolume == null || _estimatedVolume!.isEmpty) {
          _showError('Select estimated monthly procurement volume');
          return false;
        }
        if (_validateActiveSites(_activeSitesController.text) != null) {
          _showError('Enter a valid number of active construction sites');
          return false;
        }
        return true;
      case 2:
        return true;
      default:
        return true;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
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
    await authVm.registerCEO(
      fullName: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      phone: _phoneController.text,
      companyName: _companyNameController.text,
      companyType: _companyType,
      yearsInOperation: int.parse(_yearsController.text.trim()),
      registrationNumber: _ntnController.text.trim().isEmpty
          ? null
          : _ntnController.text.trim(),
      designation: _designation,
      cnic: _cnicController.text,
      city: _selectedCity!,
      address: _addressController.text,
      estimatedMonthlyVolume: _estimatedVolume!,
      activeSitesCount: int.parse(_activeSitesController.text.trim()),
      cnicFrontBytes: _cnicFrontBytes!,
      cnicBackBytes: _cnicBackBytes!,
      registrationCertBytes: _registrationCertBytes,
      officePhotoBytes: _officePhotoBytes,
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
            backgroundColor: AppColors.error,
          ),
        );
        authVm.clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.screenBg,
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
    final textTheme = Theme.of(context).textTheme;
    final subtitles = [
      'Company identity and authorized person verification',
      'Office location and procurement scale',
      'Company proof documents',
    ];
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.business_center_outlined, color: AppColors.amber),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Company Registration', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.navy)),
              Text(subtitles[_currentStep], style: textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepOne() {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionCard(
          title: 'Company Identity',
          children: [
            AuthTextField(
              label: 'COMPANY NAME',
              controller: _companyNameController,
              prefixIcon: Icons.business_outlined,
              placeholder: 'Usman Associates',
              validator: (v) => _required(v, 'Company name'),
            ),
            const SizedBox(height: 16),
            Text('COMPANY TYPE', style: textTheme.labelLarge?.copyWith(color: AppColors.navy)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _companyType,
              items: kCompanyTypes
                  .map(
                    (t) => DropdownMenuItem(
                      value: t,
                      child: Text(t, style: textTheme.bodyLarge),
                    ),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => _companyType = v ?? _companyType),
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'YEARS IN OPERATION',
              controller: _yearsController,
              prefixIcon: Icons.timeline_outlined,
              placeholder: '10',
              keyboardType: TextInputType.number,
              validator: _validateYears,
            ),
            const SizedBox(height: 16),
            AuthTextField(
              label: 'COMPANY REGISTRATION NUMBER / NTN',
              controller: _ntnController,
              prefixIcon: Icons.numbers_outlined,
              placeholder: 'Optional',
              helperText: 'Optional but improves approval chances',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'CEO / Authorized Person Identity',
          children: [
            AuthTextField(
              label: 'FULL NAME',
              controller: _nameController,
              prefixIcon: Icons.person_outline,
              placeholder: 'Ahmed Khan',
              validator: (v) => _required(v, 'Full name'),
            ),
            const SizedBox(height: 16),
            Text('DESIGNATION', style: textTheme.labelLarge?.copyWith(color: AppColors.navy)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _designation,
              items: kCeoDesignations
                  .map(
                    (d) => DropdownMenuItem(
                      value: d,
                      child: Text(d, style: textTheme.bodyLarge),
                    ),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => _designation = v ?? _designation),
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
                CnicTextInputFormatter(),
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
          ],
        ),
      ],
    );
  }

  Widget _buildStepTwo() {
    final textTheme = Theme.of(context).textTheme;
    return _sectionCard(
      title: 'Company Location & Scale',
      children: [
        Text('CITY', style: textTheme.labelLarge?.copyWith(color: AppColors.navy)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCity,
          hint: Text('Select city', style: textTheme.bodyMedium),
          isExpanded: true,
          items: kPakistanMajorCities
              .map(
                (city) => DropdownMenuItem(
                  value: city,
                  child: Text(city, style: textTheme.bodyLarge),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedCity = v),
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: 'FULL COMPANY / OFFICE ADDRESS',
          controller: _addressController,
          prefixIcon: Icons.location_on_outlined,
          placeholder: 'Office address with landmark',
          validator: (v) => _required(v, 'Company address'),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        Text('ESTIMATED MONTHLY MATERIAL PROCUREMENT VOLUME',
            style: textTheme.labelLarge?.copyWith(color: AppColors.navy)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _estimatedVolume,
          hint: Text('Select volume band', style: textTheme.bodyMedium),
          isExpanded: true,
          items: kProcurementVolumeBands
              .map(
                (band) => DropdownMenuItem(
                  value: band,
                  child: Text(band, style: textTheme.bodyLarge),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _estimatedVolume = v),
        ),
        const SizedBox(height: 16),
        AuthTextField(
          label: 'NUMBER OF ACTIVE CONSTRUCTION SITES',
          controller: _activeSitesController,
          prefixIcon: Icons.construction_outlined,
          placeholder: '3',
          keyboardType: TextInputType.number,
          validator: _validateActiveSites,
        ),
      ],
    );
  }

  Widget _buildStepThree() {
    return _sectionCard(
      title: 'Company Proof',
      subtitle:
          'Optional documents that help speed up buyer verification.',
      children: [
        _imageUploadTile(
          label: 'Company Registration Certificate or Letterhead',
          bytes: _registrationCertBytes,
          onPick: () => _pickImage((b) => _registrationCertBytes = b),
          onClear: () => setState(() => _registrationCertBytes = null),
        ),
        const SizedBox(height: 12),
        _imageUploadTile(
          label: 'Office / Site Photo',
          bytes: _officePhotoBytes,
          onPick: () => _pickImage((b) => _officePhotoBytes = b),
          onClear: () => setState(() => _officePhotoBytes = null),
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

  Widget _imageUploadTile({
    required String label,
    required Uint8List? bytes,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: textTheme.labelLarge?.copyWith(color: AppColors.navy)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: bytes == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        color:
                            AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 6),
                      Text('Tap to upload', style: textTheme.bodySmall),
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
