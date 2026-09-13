import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/admin_theme.dart';
import 'admin_commission_ledger_view.dart';
import 'admin_payment_queue_view.dart';

/// Finance hub: commission reconciliation + subscription payments.
class AdminFinanceView extends StatelessWidget {
  const AdminFinanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: AdminColors.navy,
            child: TabBar(
              isScrollable: false,
              indicatorColor: AdminColors.amber,
              indicatorWeight: 3,
              labelColor: AdminColors.amber,
              unselectedLabelColor: Colors.white70,
              labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(Icons.payment_rounded, size: 20),
                  text: 'Payment Queue',
                ),
                Tab(
                  icon: Icon(Icons.account_balance_rounded, size: 20),
                  text: 'Commission Ledger',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                AdminPaymentQueueView(embedded: true),
                const AdminCommissionLedgerView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
