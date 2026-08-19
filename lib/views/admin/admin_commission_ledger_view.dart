import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme/admin_theme.dart';
import '../../models/transaction_model.dart';
import '../../repositories/transaction_repository.dart';
import '../../utils/app_exception.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../widgets/admin/admin_widgets.dart';

class AdminCommissionLedgerView extends StatefulWidget {
  const AdminCommissionLedgerView({super.key});

  @override
  State<AdminCommissionLedgerView> createState() =>
      _AdminCommissionLedgerViewState();
}

class _AdminCommissionLedgerViewState extends State<AdminCommissionLedgerView> {
  final _currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);
  String? _settlingSupplierUid;
  String? _errorMessage;

  Future<void> _confirmSettle(SupplierUnsettledSummary supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as settled?'),
        content: Text(
          'Confirm that ${supplier.supplierName} has paid '
          '${_currency.format(supplier.unsettledAmount)} commission '
          'for ${supplier.orderCount} order(s).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AdminTheme.primaryButtonStyle(height: 44),
            child: const Text('Mark as Settled'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _settlingSupplierUid = supplier.supplierUid;
      _errorMessage = null;
    });

    try {
      await context.read<AdminViewModel>().settleSupplierCommissions(
        supplierUid: supplier.supplierUid,
        supplierName: supplier.supplierName,
        unsettledAmount: supplier.unsettledAmount,
        orderCount: supplier.orderCount,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Settled ${_currency.format(supplier.unsettledAmount)} from '
            '${supplier.supplierName}',
          ),
          backgroundColor: AdminColors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e is AppException ? e.message : e.toString();
      });
    } finally {
      if (mounted) setState(() => _settlingSupplierUid = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TransactionRepository>();

    return StreamBuilder<CommissionLedgerSnapshot>(
      stream: repo.watchCommissionLedger(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                snapshot.error.toString(),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: AdminColors.red),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final ledger = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AdminColors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AdminColors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _errorMessage!,
                  style: GoogleFonts.plusJakartaSans(
                    color: AdminColors.red,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            _SummaryStrip(
              outstanding: ledger.outstandingThisMonth,
              collected: ledger.collectedThisMonth,
              grandTotal: ledger.grandTotalCollected,
              currency: _currency,
            ),
            const SizedBox(height: 20),
            const AdminSectionLabel('Outstanding Commissions'),
            const SizedBox(height: 12),
            if (ledger.suppliers.isEmpty)
              AdminCard(
                child: Center(
                  child: Text(
                    'No suppliers with unsettled commissions.',
                    style: AdminTheme.mutedStyle(),
                  ),
                ),
              )
            else
              ...ledger.suppliers.map(
                (supplier) => _SupplierLedgerCard(
                  supplier: supplier,
                  currency: _currency,
                  isSettling: _settlingSupplierUid == supplier.supplierUid,
                  onSettle: () => _confirmSettle(supplier),
                ),
              ),
          ],
        );
      },
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
            Expanded(
              child: _SummaryCard(
                label: 'Outstanding this month',
                value: currency.format(outstanding),
                icon: Icons.pending_actions_outlined,
                color: AdminColors.amber,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'Collected this month',
                value: currency.format(collected),
                icon: Icons.check_circle_outline,
                color: AdminColors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SummaryCard(
          label: 'Grand total ever collected',
          value: currency.format(grandTotal),
          icon: Icons.account_balance_wallet_outlined,
          color: AdminColors.navy,
          fullWidth: true,
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool fullWidth;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: AdminTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AdminColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: AdminTheme.mutedStyle(size: 10)),
        ],
      ),
    );
  }
}

class _SupplierLedgerCard extends StatelessWidget {
  final SupplierUnsettledSummary supplier;
  final NumberFormat currency;
  final bool isSettling;
  final VoidCallback onSettle;

  const _SupplierLedgerCard({
    required this.supplier,
    required this.currency,
    required this.isSettling,
    required this.onSettle,
  });

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AdminColors.amber.withValues(alpha: 0.15),
            child: const Icon(
              Icons.storefront_outlined,
              size: 18,
              color: AdminColors.amber,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supplier.supplierName,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AdminColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${currency.format(supplier.unsettledAmount)} · '
                  '${supplier.orderCount} order(s)',
                  style: AdminTheme.mutedStyle(size: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: isSettling ? null : onSettle,
            style: AdminTheme.primaryButtonStyle(height: 40).copyWith(
              minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            child: isSettling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Mark as Settled',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }
}
