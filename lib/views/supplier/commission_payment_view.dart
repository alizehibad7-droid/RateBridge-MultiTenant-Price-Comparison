import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/payment_proof_model.dart';
import '../../theme/supplier_theme.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../payment/payment_method_view.dart';

class CommissionPaymentView extends StatefulWidget {
  const CommissionPaymentView({super.key});

  @override
  State<CommissionPaymentView> createState() => _CommissionPaymentViewState();
}

class _CommissionPaymentViewState extends State<CommissionPaymentView> {
  final _amountController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _proceedToPayment(double totalOwed) {
    final input = double.tryParse(_amountController.text.trim());

    if (input == null || input <= 0) {
      setState(() => _error = 'Please enter a valid amount');
      return;
    }

    if (input > totalOwed + 0.01) {
      setState(
        () => _error =
            'Amount cannot exceed ${CurrencyFormatter.formatPKR(totalOwed)}',
      );
      return;
    }

    setState(() => _error = null);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentMethodView(
          amount: input,
          type: PaymentType.commission,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: const SupplierAppBar(title: 'Pay Commission'),
      body: Consumer<SupplierViewModel>(
        builder: (context, viewModel, child) {
          final owed = viewModel.commissionOwed;

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
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      FieldColors.primaryNavy,
                      FieldColors.primaryNavyDark,
                    ],
                  ),
                  borderRadius: BorderRadius.all(
                    Radius.circular(FieldRadius.card),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OUTSTANDING COMMISSION',
                      style: AppTextStyles.label.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.formatPKR(owed),
                      style: FieldTypography.displayLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: FieldSpacing.lg),
              Text(
                'Payment amount',
                style: AppTextStyles.h3.copyWith(
                  color: FieldColors.primaryNavy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: FieldSpacing.sm),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: SupplierTheme.fieldDecoration(
                  labelText: 'Amount',
                  hintText: 'e.g. 5000',
                ).copyWith(
                  prefixText: 'Rs. ',
                  errorText: _error,
                ),
                style: AppTextStyles.body,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: FieldSpacing.sm),
              Wrap(
                spacing: 8,
                children: [
                  _QuickAmountChip(
                    label: 'Pay full',
                    onTap: () => setState(
                      () => _amountController.text = owed.toStringAsFixed(0),
                    ),
                  ),
                  if (owed > 5000)
                    _QuickAmountChip(
                      label: 'Rs. 5,000',
                      onTap: () => setState(() => _amountController.text = '5000'),
                    ),
                ],
              ),
              const SizedBox(height: FieldSpacing.xl),
              FilledButton(
                onPressed: () => _proceedToPayment(owed),
                child: const Text('Continue to payment'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickAmountChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: AppTextStyles.caption.copyWith(
        fontWeight: FontWeight.w600,
        color: FieldColors.primaryNavy,
      )),
      onPressed: onTap,
      backgroundColor: FieldColors.surfaceWhite,
      side: const BorderSide(color: FieldColors.borderSubtle),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }
}
