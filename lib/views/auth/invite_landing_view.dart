import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/company_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/invite_viewmodel.dart';
import '../../services/firestore_service.dart';
import '../../constants/route_names.dart';
import '../../constants/app_colors.dart';
import '../../utils/app_navigation.dart';

class InviteLandingView extends StatefulWidget {
  final String companyId;
  final String code;

  const InviteLandingView({
    super.key,
    required this.companyId,
    required this.code,
  });

  @override
  State<InviteLandingView> createState() => _InviteLandingViewState();
}

class _InviteLandingViewState extends State<InviteLandingView> {
  bool _isValidating = true;
  String? _validationError;
  CompanyModel? _company;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateInvitation();
    });
  }

  Future<void> _validateInvitation() async {
    setState(() {
      _isValidating = true;
      _validationError = null;
    });

    try {
      final token = widget.code;
      final inviteVM = Provider.of<InviteViewModel>(context, listen: false);
      
      await inviteVM.loadInvitation(token);
      
      if (inviteVM.error != null) {
        throw Exception(inviteVM.error);
      }

      final invitation = inviteVM.invitation;
      if (invitation == null) {
        throw Exception("Invitation record not found or code is invalid.");
      }

      if (invitation.status.toLowerCase() != 'pending') {
        throw Exception("This invitation has already been ${invitation.status.toLowerCase()}.");
      }

      if (invitation.isExpired) {
        throw Exception("This invitation has expired.");
      }

      if (!mounted) return;
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final company = await firestoreService.getCompany(invitation.companyId);

      if (mounted) {
        setState(() {
          _company = company;
          _isValidating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _validationError = e.toString().replaceAll('Exception: ', '');
          _isValidating = false;
        });
      }
    }
  }

  void _accept() async {
    final token = widget.code;
    final inviteVM = Provider.of<InviteViewModel>(context, listen: false);
    
    await inviteVM.acceptInvite(token);
    
    if (!mounted) return;

    if (inviteVM.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Team invitation accepted! Redirecting..."), 
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go(RouteNames.fieldHome);
    } else {
      final err = inviteVM.error ?? "Failed to accept the invitation.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err), 
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inviteVM = Provider.of<InviteViewModel>(context);
    final authViewModel = Provider.of<AuthViewModel>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.screenBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppNavigation.leading(context),
        title: const Text('Team Invitation'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
          child: _isValidating
              ? const CircularProgressIndicator(
                  color: AppColors.amber,
                  strokeWidth: 2,
                )
              : _validationError != null
                  ? _buildErrorUI(_validationError!, theme)
                  : _buildInvitationDetailsUI(authViewModel, inviteVM, theme),
        ),
      ),
    );
  }

  Widget _buildErrorUI(String message, ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.error, weight: 300),
        ),
        const SizedBox(height: 32),
        Text(
          "Invalid Invitation Link",
          style: theme.textTheme.displayLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          child: _PressableScale(
            onTap: () => context.go(RouteNames.login),
            child: ElevatedButton(
              onPressed: () => context.go(RouteNames.login),
              child: const Text("RETURN TO SIGN IN"),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInvitationDetailsUI(AuthViewModel authVM, InviteViewModel inviteVM, ThemeData theme) {
    final companyName = _company?.name ?? "RateBridge Builder Firm";
    final isLoggedIn = authVM.user != null;
    final invitation = inviteVM.invitation;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 64,
            color: AppColors.navy,
            weight: 300,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          "Corporate Invitation",
          style: theme.textTheme.displayLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: 12),
        Text(
          "Securely onboarding onto RateBridge Procurement Space",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 48),
        
        // Skyline Detail Card
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow("INVITED EMAIL", invitation?.email ?? "", theme),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: AppColors.border)),
              _infoRow("CORPORATE ENTITY", companyName, theme),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: AppColors.border)),
              _infoRow("ASSIGNED ROLE", invitation?.role?.toUpperCase() ?? "FIELD USER", theme),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: AppColors.border)),
              _infoRow("VOUCHER CODE", widget.code, theme, isCode: true),
            ],
          ),
        ),
        const SizedBox(height: 48),

        if (isLoggedIn) ...[
          SizedBox(
            width: double.infinity,
            child: _PressableScale(
              onTap: inviteVM.isLoading ? () {} : _accept,
              child: ElevatedButton(
                onPressed: inviteVM.isLoading ? null : _accept,
                child: inviteVM.isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("ACCEPT & SECURE ACCOUNT"),
              ),
            ),
          ),
        ] else ...[
          Text(
            "An account is required to join this corporate workspace:",
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _PressableScale(
                  onTap: () => context.push(RouteNames.registerFieldUser),
                  child: OutlinedButton(
                    onPressed: () => context.push(RouteNames.registerFieldUser),
                    child: const Text("SIGN UP"),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _PressableScale(
                  onTap: () => context.push(RouteNames.login),
                  child: ElevatedButton(
                    onPressed: () => context.push(RouteNames.login),
                    child: const Text("SIGN IN"),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _infoRow(String label, String value, ThemeData theme, {bool isCode = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: theme.textTheme.labelLarge?.copyWith(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.textPrimary, 
            fontSize: 15, 
            fontWeight: FontWeight.w700,
            fontFamily: isCode ? 'monospace' : null,
            letterSpacing: isCode ? 2.0 : null,
          ),
        ),
      ],
    );
  }
}

class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableScale({required this.child, required this.onTap});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
