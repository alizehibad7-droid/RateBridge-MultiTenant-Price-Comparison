import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../repositories/transaction_repository.dart';
import '../../services/stripe_service.dart';
import '../../theme/supplier_theme.dart';
import '../../utils/app_exception.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/supplier_viewmodel.dart';

class CommissionPaymentView extends StatefulWidget {
  const CommissionPaymentView({super.key});

  @override
  State<CommissionPaymentView> createState() => _CommissionPaymentViewState();
}

class _CommissionPaymentViewState extends State<CommissionPaymentView> {
  final _amountController = TextEditingController();
  String? _error;
  bool _paying = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _proceedToPayment(double totalOwed, List<String> txIds) async {
    final owed = CurrencyFormatter.roundToRupee(totalOwed);
    final input = CurrencyFormatter.roundToRupee(
      double.tryParse(_amountController.text.trim()) ?? 0,
    );

    if (input <= 0) {
      setState(() => _error = 'Please enter a valid amount');
      return;
    }

    if (input > owed) {
      setState(
        () => _error =
            'Amount cannot exceed ${CurrencyFormatter.formatPKR(owed)}',
      );
      return;
    }

    if (txIds.isEmpty) {
      setState(() => _error = 'No unsettled commission transactions found.');
      return;
    }

    setState(() {
      _error = null;
      _paying = true;
    });

    try {
      final stripe = context.read<StripeService>();
      final txRepo = context.read<TransactionRepository>();
      final authVM = context.read<AuthViewModel>();
      final supplierUid = authVM.user?.uid ?? '';

      await stripe.payWithStripe(
        amountPKR: input.round(),
        type: 'commission',
        transactionIds: txIds,
      );

      if (supplierUid.isNotEmpty) {
        await txRepo.settleSupplierCommissions(supplierUid, txIds);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment successful! Commissions settled.'),
        ),
      );
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is AppException ? e.message : e.toString();
      });
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: const SupplierAppBar(title: 'Pay Commission'),
      body: Consumer<SupplierViewModel>(
        builder: (context, viewModel, child) {
          final owed = viewModel.commissionOwed;
          final txIds = viewModel.unsettledTransactionIds;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              FieldSpacing.md,
              FieldSpacing.md,
              FieldSpacing.md,
              FieldSpacing.xl,
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(FieldSpacing.md),
                decoration: BoxDecoration(
                  color: FieldColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FieldColors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outstanding commission',
                      style: FieldTypography.labelSmall.copyWith(
                        color: FieldColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      CurrencyFormatter.formatPKR(owed),
                      style: FieldTypography.headlineMedium.copyWith(
                        color: FieldColors.primaryNavy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: FieldSpacing.lg),
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: SupplierTheme.fieldDecoration(
                  labelText: 'Amount to pay (Rs)',
                  hintText: 'Enter amount',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: FieldSpacing.sm),
                Text(
                  _error!,
                  style: const TextStyle(color: FieldColors.statusDanger),
                ),
              ],
              const SizedBox(height: FieldSpacing.xl),
              FilledButton(
                onPressed: _paying || owed <= 0
                    ? null
                    : () => _proceedToPayment(owed, txIds),
                child: _paying
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Pay with Stripe'),
              ),
            ],
          );
        },
      ),
    );
  }
}
