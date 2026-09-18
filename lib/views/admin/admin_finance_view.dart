import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/admin_theme.dart';
import 'admin_commission_ledger_view.dart';
import 'admin_payment_queue_view.dart';
import 'package:flutter/foundation.dart';
/// Finance hub: commission reconciliation + subscription payments.
class AdminFinanceView extends StatelessWidget {
  const AdminFinanceView({super.key});

  bool get _isDesktop {
    if (kIsWeb) return true;
    try {
      final platform = defaultTargetPlatform;
      return platform == TargetPlatform.windows || platform == TargetPlatform.macOS || platform == TargetPlatform.linux;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: _isDesktop ? Colors.white : AdminColors.navy,
            child: TabBar(
              isScrollable: false,
              indicatorColor: AdminColors.amber,
              indicatorWeight: 3,
              labelColor: AdminColors.amber,
              unselectedLabelColor: _isDesktop ? AdminColors.textGrey : Colors.white70,
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
          if (_isDesktop)
            const Divider(height: 1, color: AdminColors.border),
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
