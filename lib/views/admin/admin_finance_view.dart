import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../theme/admin_theme.dart';
import '../../viewmodels/admin_viewmodel.dart';
import 'admin_commission_ledger_view.dart';
import 'admin_payment_queue_view.dart';

/// Finance hub: commission reconciliation + subscription payments.
/// Reverted to the 2-tab layout while maintaining real Stripe/Subscription data.
class AdminFinanceView extends StatelessWidget {
  final int initialTab;
  const AdminFinanceView({this.initialTab = 0, super.key});

  bool _checkIsDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1024;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = _checkIsDesktop(context);
    final adminVM = context.watch<AdminViewModel>();
    
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab.clamp(0, 1),
      child: Column(
        children: [
          Material(
            color: isDesktop ? Colors.white : AdminColors.navy,
            child: TabBar(
              isScrollable: false,
              indicatorColor: AdminColors.amber,
              indicatorWeight: 3,
              labelColor: AdminColors.amber,
              unselectedLabelColor: isDesktop ? AdminColors.textGrey : Colors.white70,
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
          if (isDesktop)
            const Divider(height: 1, color: AdminColors.border),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => adminVM.loadPaymentQueue(),
              child: TabBarView(
                children: [
                  AdminPaymentQueueView(embedded: true),
                  const AdminCommissionLedgerView(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
