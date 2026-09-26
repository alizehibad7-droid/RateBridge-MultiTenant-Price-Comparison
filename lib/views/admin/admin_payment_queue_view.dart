import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../theme/admin_theme.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../widgets/admin/admin_widgets.dart';

class AdminPaymentQueueView extends StatefulWidget {
  final bool embedded;

  const AdminPaymentQueueView({super.key, this.embedded = false});

  @override
  State<AdminPaymentQueueView> createState() => _AdminPaymentQueueViewState();
}

class _AdminPaymentQueueViewState extends State<AdminPaymentQueueView> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminViewModel>().loadDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminVM = context.watch<AdminViewModel>();
    final txs = adminVM.transactions;

    return Column(
      children: [
        if (!widget.embedded)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Text(
              'Payment History',
              style: AdminTheme.titleStyle(size: 20),
            ),
          ),
        Expanded(
          child: _buildTransactionList(txs, adminVM),
        ),
      ],
    );
  }

  Widget _buildTransactionList(List<PlatformTransaction> transactions, AdminViewModel vm) {
    if (vm.isLoading && transactions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AdminColors.navy.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.payments_rounded, 
                size: 64, 
                color: AdminColors.textGrey.withValues(alpha: 0.5)
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No payment history yet',
              style: AdminTheme.titleStyle(size: 18).copyWith(color: AdminColors.textGrey),
            ),
            const SizedBox(height: 8),
            Text(
              'Confirmed payments will appear here',
              style: AdminTheme.mutedStyle(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => vm.loadDashboardData(),
      color: AdminColors.amber,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildTransactionCard(transactions[index]);
        },
      ),
    );
  }

  Widget _buildTransactionCard(PlatformTransaction tx) {
    return AdminCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AdminColors.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              tx.type == 'subscription' ? Icons.workspace_premium_rounded : Icons.account_balance_wallet_rounded,
              color: AdminColors.navy,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.companyName,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AdminColors.navy,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AdminColors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tx.type.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AdminColors.darkAmber,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tx.date != null ? DateFormat('MMM dd, yyyy').format(tx.date!) : 'N/A',
                      style: AdminTheme.mutedStyle(size: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rs ${tx.amount.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AdminColors.navy,
                ),
              ),
              StatusChip(status: tx.status),
            ],
          ),
        ],
      ),
    );
  }
}
