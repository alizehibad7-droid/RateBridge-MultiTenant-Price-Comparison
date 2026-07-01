import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
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
        backgroundColor: vm.error != null ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SubscriptionViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payment Details',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'These details are shown to CEOs when they pay for a subscription via JazzCash or bank transfer.',
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _jazzCashController,
            decoration: const InputDecoration(
              labelText: 'JazzCash number',
              hintText: '03XX XXXXXXX',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bankNameController,
            decoration: const InputDecoration(labelText: 'Bank name'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _accountTitleController,
            decoration: const InputDecoration(labelText: 'Account title'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _accountNumberController,
            decoration: const InputDecoration(labelText: 'Bank account number'),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: vm.isLoading ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: vm.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save payment details'),
          ),
        ],
      ),
    );
  }
}
