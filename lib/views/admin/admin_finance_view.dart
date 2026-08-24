import 'package:flutter/material.dart';

import '../../theme/admin_theme.dart';
import 'admin_commission_ledger_view.dart';
import 'admin_commission_policy_view.dart';
import 'admin_payment_queue_view.dart';

/// Finance hub: commission reconciliation + subscription payments.
class AdminFinanceView extends StatelessWidget {
  const AdminFinanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color: AdminColors.navy,
            child: TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Payment Queue'),
                Tab(text: 'Commission Ledger'),
                Tab(text: 'Commission Policy'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                AdminPaymentQueueView(embedded: true),
                AdminCommissionLedgerView(),
                AdminCommissionPolicyView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
