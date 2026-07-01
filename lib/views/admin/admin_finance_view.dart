import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import 'admin_commission_ledger_view.dart';
import 'admin_payment_queue_view.dart';
import 'admin_subscription_payments_view.dart';

/// Finance hub: commission reconciliation + subscription payments.
class AdminFinanceView extends StatelessWidget {
  const AdminFinanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
              isScrollable: true,
              tabs: [
                Tab(text: 'Subscription Payments'),
                Tab(text: 'Payment Queue'),
                Tab(text: 'Commission Ledger'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                AdminSubscriptionPaymentsView(),
                AdminPaymentQueueView(),
                AdminCommissionLedgerView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
