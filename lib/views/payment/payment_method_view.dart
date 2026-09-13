import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../utils/app_navigation.dart';
import '../../models/payment_proof_model.dart';
import 'upload_proof_view.dart';

class PaymentMethodView extends StatelessWidget {
  final double amount;
  final PaymentType type;
  final String? planKey;
  final List<String>? relatedTransactionIds;

  const PaymentMethodView({
    super.key,
    required this.amount,
    required this.type,
    this.planKey,
    this.relatedTransactionIds,
  });

  @override
  Widget build(BuildContext context) {
    // DUMMY ACCOUNT DETAILS FOR TESTING
    final Map<String, Map<String, String>> testAccounts = {
      'easypaisa': {'name': 'TEST ADMIN', 'number': '03000000001'},
      'jazzcash': {'name': 'TEST ADMIN', 'number': '03000000000'},
      'bank': {'name': 'TEST ADMIN BANK', 'number': '0000000000000000', 'bank': 'Test Bank'},
    };

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppNavigation.leading(context),
        title: const Text('Select Payment Method'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount to Pay: Rs. $amount', 
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.navy)),
            const SizedBox(height: 8),
            const Text('Choose a method and transfer manually to see dummy details.', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 32),
            _methodItem(context, 'Easypaisa', 'easypaisa', Icons.account_balance_wallet, AppColors.success, testAccounts['easypaisa']!),
            const SizedBox(height: 12),
            _methodItem(context, 'JazzCash', 'jazzcash', Icons.phone_android, AppColors.warning, testAccounts['jazzcash']!),
            const SizedBox(height: 12),
            _methodItem(context, 'Bank Transfer', 'bank', Icons.account_balance, AppColors.statusInfo, testAccounts['bank']!),
          ],
        ),
      ),
    );
  }

  Widget _methodItem(BuildContext context, String title, String key, IconData icon, Color color, Map<String, String> details) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UploadProofView(
              amount: amount,
              type: type,
              method: key,
              planKey: planKey,
              relatedTransactionIds: relatedTransactionIds,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${details['number']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
