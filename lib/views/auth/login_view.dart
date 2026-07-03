import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../constants/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';

const _navy = Color(0xFF1E326E);
const _amber = Color(0xFFFBB03C);
const _screenBg = Color(0xFFF5F6FA);
const _fieldBg = Color(0xFFF5F6FA);
const _borderGrey = Color(0xFFE2E5F0);

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
    // Normalize role string to handle variations like 'field_user' vs 'fielduser'
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

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _borderGrey),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: Colors.grey.shade500,
      ),
      prefixIcon: Icon(prefixIcon, color: Colors.grey.shade500, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _fieldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _amber, width: 2),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: Color(0xFFE53935)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();

    return Scaffold(
      backgroundColor: _screenBg,
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: BoxDecoration(
          color: _screenBg,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _navy.withValues(alpha: 0.07),
              _screenBg,
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
                        color: _navy,
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _navy,
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
                            color: _navy.withValues(alpha: 0.08),
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
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: _navy,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Sign in to your account',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'Email Address',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _navy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                              style: GoogleFonts.plusJakartaSans(fontSize: 14),
                              decoration: _fieldDecoration(
                                hint: 'Enter your email',
                                prefixIcon: Icons.email_outlined,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Password',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _navy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              validator: _validatePassword,
                              style: GoogleFonts.plusJakartaSans(fontSize: 14),
                              decoration: _fieldDecoration(
                                hint: 'Enter your password',
                                prefixIcon: Icons.lock_outlined,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.grey.shade500,
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
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _amber,
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
                                  color: const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Color(0xFFE53935),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        authVm.errorMessage!,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFFE53935),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: _amber.withValues(alpha: 0.32),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: authVm.isLoading
                                      ? null
                                      : () => _submit(authVm),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _amber,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        _amber.withValues(alpha: 0.65),
                                    elevation: 0,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: authVm.isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          'Sign In',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Colors.grey.shade300,
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: Text(
                                    'or',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Colors.grey.shade300,
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              "Don't have an account?",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton(
                                onPressed: () =>
                                    context.push(RouteNames.roleSelection),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _navy,
                                  side: const BorderSide(
                                    color: _navy,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Create Account',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _navy,
                                  ),
                                ),
                              ),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}
