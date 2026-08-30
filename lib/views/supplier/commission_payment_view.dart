import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/supplier_theme.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../models/payment_proof_model.dart';
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
      setState(() => _error = 'Amount cannot exceed Rs. ${totalOwed.toStringAsFixed(0)}');
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
      appBar: AppBar(title: const Text('Pay Commission')),
      body: Consumer<SupplierViewModel>(
        builder: (context, viewModel, child) {
          final owed = viewModel.commissionOwed;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: FieldColors.primaryNavy,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Outstanding Commission', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(CurrencyFormatter.formatPKR(owed), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text('Enter Payment Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: 'Rs. ',
                    hintText: 'e.g. 5000',
                    errorText: _error,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _QuickAmountButton(
                      label: 'Pay Full', 
                      onTap: () => setState(() => _amountController.text = owed.toStringAsFixed(0))
                    ),
                    const SizedBox(width: 8),
                    if (owed > 5000)
                      _QuickAmountButton(
                        label: 'Rs. 5,000', 
                        onTap: () => setState(() => _amountController.text = '5000')
                      ),
                  ],
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _proceedToPayment(owed),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FieldColors.primaryNavy,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('CONTINUE TO PAYMENT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickAmountButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white,
      labelStyle: const TextStyle(color: FieldColors.primaryNavy, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade300)),
    );
  }
}
