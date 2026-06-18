import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/field_user_viewmodel.dart';
import '../../viewmodels/locale_viewmodel.dart';
import '../../widgets/app_text_field.dart';
import '../../constants/app_colors.dart';

class FieldProfileView extends StatefulWidget {
  const FieldProfileView({super.key});

  @override
  State<FieldProfileView> createState() => _FieldProfileViewState();
}

class _FieldProfileViewState extends State<FieldProfileView> {
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<FieldUserViewModel>();
      await vm.loadProfile();
      if (!mounted) return;
      setState(() {
        _fullName.text = vm.fullName;
        _phone.text = vm.phone;
        _email.text = vm.email;
        _initialized = true;
      });
    });
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save(FieldUserViewModel vm) async {
    final success = await vm.updateProfile({
      'fullName': _fullName.text.trim(),
      'phone': _phone.text.trim(),
    });
    
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green),
      );
    } else if (vm.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error!), backgroundColor: Colors.red),
      );
    }
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need to sign in again to access the field console.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthViewModel>().signOut();
              if (context.mounted) context.go('/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sign Out', style: AppTextStyles.button),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: Consumer<FieldUserViewModel>(
        builder: (context, vm, _) {
          if (!_initialized) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---- Header ----
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.fieldAccent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.fieldAccent, width: 1.4),
                        ),
                        child: Text(
                          vm.fullName.isNotEmpty
                              ? vm.fullName[0].toUpperCase()
                              : 'F',
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppColors.fieldAccent),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        vm.fullName.isNotEmpty ? vm.fullName : 'Field User',
                        style: AppTextStyles.h2,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.fieldAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Text(
                          'FIELD OPERATIONS',
                          style: TextStyle(
                            color: AppColors.fieldAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      if (vm.joinedAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Field Member since ${AppFormatters.date(vm.joinedAt!)}',
                          style: AppTextStyles.bodyMuted,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ---- Account details ----
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: appCardDecoration(shadow: AppShadows.card),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Account Details',
                          style: TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 15)),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'FULL NAME',
                        controller: _fullName,
                        prefixIcon: Icons.person_outline,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'EMAIL ADDRESS',
                        controller: _email,
                        prefixIcon: Icons.email_outlined,
                        readOnly: true,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        label: 'PHONE NUMBER',
                        controller: _phone,
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ---- Site Access Note ----
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.infoBg,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Site Logistics Access',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 2),
                            Text(
                              'Your account is linked to ${vm.companyName}. '
                              'You can manage procurements and verify site deliveries '
                              'for this company.',
                              style: AppTextStyles.bodyMuted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ---- Language ----
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: appCardDecoration(shadow: AppShadows.card),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Language',
                          style: TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 15)),
                      const SizedBox(height: 12),
                      Consumer<LocaleViewModel>(
                        builder: (context, localeVm, _) {
                          return DropdownButtonFormField<String>(
                            value: localeVm.languageCode,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'en', child: Text('English')),
                              DropdownMenuItem(
                                  value: 'ur', child: Text('اردو')),
                              DropdownMenuItem(
                                  value: 'ur_roman',
                                  child: Text('Roman Urdu')),
                            ],
                            onChanged: (val) {
                              if (val != null) localeVm.setLocale(val);
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: vm.isLoading ? null : () => _save(vm),
                    child: vm.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.4),
                          )
                        : const Text('Save Changes',
                            style: AppTextStyles.button),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => _confirmSignOut(context),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger)),
                    child: const Text('Sign Out'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
