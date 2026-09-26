import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme/admin_theme.dart';
import '../../models/transaction_model.dart';
import '../../repositories/transaction_repository.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../widgets/admin/admin_widgets.dart';

class AdminCommissionLedgerView extends StatefulWidget {
  const AdminCommissionLedgerView({super.key});

  @override
  State<AdminCommissionLedgerView> createState() => _AdminCommissionLedgerViewState();
}

class _AdminCommissionLedgerViewState extends State<AdminCommissionLedgerView> {
  final _currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);
  Stream<CommissionLedgerSnapshot>? _ledgerStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ledgerStream ??=
        context.read<TransactionRepository>().watchCommissionLedger();
  }

  @override
  Widget build(BuildContext context) {
    final adminVM = context.watch<AdminViewModel>();

    return StreamBuilder<CommissionLedgerSnapshot>(
      stream: _ledgerStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final ledger = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () => adminVM.loadDashboardData(),
          color: AdminColors.amber,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryStrip(
                outstanding: ledger.outstandingThisMonth,
                collected: ledger.collectedThisMonth,
                grandTotal: ledger.grandTotalCollected,
                currency: _currency,
              ),
              const SizedBox(height: 28),
        
              const Row(
                children: [
                  Icon(Icons.store_rounded, color: AdminColors.navy, size: 18),
                  SizedBox(width: 8),
                  AdminSectionLabel('Supplier Balances'),
                ],
              ),
              const SizedBox(height: 12),
              if (ledger.suppliers.isEmpty)
                AdminCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, color: AdminColors.green.withValues(alpha: 0.5), size: 40),
                          const SizedBox(height: 12),
                          const Text('No outstanding commissions.', style: TextStyle(color: AdminColors.textGrey, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                )
              else
                ...ledger.suppliers.map((s) => _SupplierBalanceTile(supplier: s, currency: _currency)),
            ],
          ),
        );
      },
    );
  }
}

class _SupplierBalanceTile extends StatelessWidget {
  final SupplierUnsettledSummary supplier;
  final NumberFormat currency;
  const _SupplierBalanceTile({required this.supplier, required this.currency});

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AdminColors.red.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.store_rounded, color: AdminColors.textGrey, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(supplier.supplierName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AdminColors.navy)),
                Text('${supplier.orderCount} orders pending', style: AdminTheme.mutedStyle(size: 11).copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(currency.format(supplier.unsettledAmount), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AdminColors.red, fontSize: 15)),
              const Text('OUTSTANDING', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AdminColors.red, letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final double outstanding;
  final double collected;
  final double grandTotal;
  final NumberFormat currency;

  const _SummaryStrip({
    required this.outstanding,
    required this.collected,
    required this.grandTotal,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _StatCard(Icons.account_balance_wallet_rounded, 'Owed (Total)', currency.format(outstanding), AdminColors.red)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(Icons.assignment_turned_in_rounded, 'Collected (MTD)', currency.format(collected), AdminColors.green)),
          ],
        ),
        const SizedBox(height: 12),
        _StatCard(Icons.bar_chart_rounded, 'Total Commission Revenue', currency.format(grandTotal), AdminColors.navy, isFull: true),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isFull;
  const _StatCard(this.icon, this.label, this.value, this.color, {this.isFull = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isFull ? double.infinity : null,
      padding: const EdgeInsets.all(20),
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 16),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.5)),
          Text(label.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w800, color: AdminColors.textGrey, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}
