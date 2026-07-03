import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../theme/admin_theme.dart';
import '../../models/payment_details_config.dart';
import '../../viewmodels/subscription_viewmodel.dart';

class AdminPaymentSettingsView extends StatefulWidget {
  const AdminPaymentSettingsView({super.key});

  @override
  State<AdminPaymentSettingsView> createState() =>
      _AdminPaymentSettingsViewState();
}

class _AdminPaymentSettingsViewState extends State<AdminPaymentSettingsView> {
  final _jazzCashController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountTitleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDetails());
  }

  Future<void> _loadDetails() async {
    final vm = context.read<SubscriptionViewModel>();
    await vm.loadPaymentDetails();
    if (!mounted) return;
    final details = vm.paymentDetails;
    _jazzCashController.text = details.jazzCashNumber;
    _bankNameController.text = details.bankName;
    _accountNumberController.text = details.bankAccountNumber;
    _accountTitleController.text = details.accountTitle;
    setState(() {});
  }

  @override
  void dispose() {
    _jazzCashController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountTitleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final config = PaymentDetailsConfig(
      jazzCashNumber: _jazzCashController.text,
      bankName: _bankNameController.text,
      bankAccountNumber: _accountNumberController.text,
      accountTitle: _accountTitleController.text,
    );
    await context.read<SubscriptionViewModel>().savePaymentDetails(config);
    if (!mounted) return;
    final vm = context.read<SubscriptionViewModel>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(vm.error ?? vm.successMessage ?? 'Saved'),
        backgroundColor:
            vm.error != null ? AdminColors.red : AdminColors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SubscriptionViewModel>();

    return Scaffold(
      backgroundColor: AdminColors.screenBg,
      appBar: const AdminAppBar(title: 'Payment Details'),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'These details are shown to CEOs when they pay for a subscription via JazzCash or bank transfer.',
            style: AdminTheme.mutedStyle().copyWith(height: 1.4),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _jazzCashController,
            decoration: AdminTheme.inputDecoration(
              labelText: 'JazzCash number',
              hintText: '03XX XXXXXXX',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bankNameController,
            decoration: AdminTheme.inputDecoration(labelText: 'Bank name'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _accountTitleController,
            decoration: AdminTheme.inputDecoration(labelText: 'Account title'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _accountNumberController,
            decoration:
                AdminTheme.inputDecoration(labelText: 'Bank account number'),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: vm.isLoading ? null : _save,
            style: AdminTheme.primaryButtonStyle(height: 52),
            child: vm.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Save payment details',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
