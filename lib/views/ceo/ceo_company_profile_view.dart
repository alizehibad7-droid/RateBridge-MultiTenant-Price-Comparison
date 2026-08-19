import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/route_names.dart';
import '../../theme/ceo_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../widgets/ceo_nav_bar.dart';

class CeoCompanyProfileView extends StatefulWidget {
  const CeoCompanyProfileView({super.key});

  @override
  State<CeoCompanyProfileView> createState() => _CeoCompanyProfileViewState();
}

class _CeoCompanyProfileViewState extends State<CeoCompanyProfileView> {
  final _thresholdController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final company = context.read<CeoViewModel>().company;
    _thresholdController.text = company?.autoApprovalThreshold.toStringAsFixed(0) ?? '0';
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _updateThreshold() async {
    final val = double.tryParse(_thresholdController.text.trim());
    if (val == null || val < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<CeoViewModel>().updateCompanyProfile({
        'autoApprovalThreshold': val,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto-approval threshold updated')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            style: CeoTheme.destructiveButtonStyle(height: 40),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await context.read<AuthViewModel>().signOut();
    if (context.mounted) {
      context.go(RouteNames.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = context.watch<CeoViewModel>().company;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: const CeoAppBar(title: 'Company Settings'),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Procurement Settings', style: CeoTheme.titleStyle()),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: CeoTheme.cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CeoSectionLabel('Auto-Approval Threshold'),
                const SizedBox(height: 8),
                Text(
                  'Orders below this amount (PKR) are sent directly to the supplier without your manual approval.',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _thresholdController,
                        keyboardType: TextInputType.number,
                        decoration: CeoTheme.inputDecoration(
                          labelText: 'Amount (PKR)',
                          hintText: 'e.g. 5000',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _updateThreshold,
                        child: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('SAVE'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text('Account', style: CeoTheme.titleStyle()),
          const SizedBox(height: 16),
          Container(
            decoration: CeoTheme.cardDecoration(),
            child: ListTile(
              leading: const Icon(Icons.logout, color: CeoColors.red),
              title: Text(
                'Log out',
                style: textTheme.bodyLarge?.copyWith(
                  color: CeoColors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => _logout(context),
            ),
          ),
          const SizedBox(height: 40),
          Center(
            child: Text(
              'Company: ${company?.name ?? "..."}\nID: ${company?.id ?? "..."}',
              textAlign: TextAlign.center,
              style: textTheme.labelSmall,
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CeoNavBar(currentIndex: 5),
    );
  }
}
