import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/transaction_model.dart';
import '../../repositories/transaction_repository.dart';
import '../../utils/app_exception.dart';

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
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
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
      await context
          .read<TransactionRepository>()
          .settleSupplierCommissions(supplier.supplierUid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Settled ${_currency.format(supplier.unsettledAmount)} from '
            '${supplier.supplierName}',
          ),
          backgroundColor: AppColors.success,
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
                style: const TextStyle(color: AppColors.error),
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
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
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
            const Text(
              'OUTSTANDING COMMISSIONS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            if (ledger.suppliers.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text(
                    'No suppliers with unsettled commissions.',
                    style: TextStyle(color: AppColors.textSecondary),
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
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'Collected this month',
                value: currency.format(collected),
                icon: Icons.check_circle_outline,
                color: AppColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _SummaryCard(
          label: 'Grand total ever collected',
          value: currency.format(grandTotal),
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.primary,
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.warning.withValues(alpha: 0.12),
              child: const Icon(
                Icons.storefront_outlined,
                size: 18,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supplier.supplierName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${currency.format(supplier.unsettledAmount)} · '
                    '${supplier.orderCount} order(s)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: isSettling ? null : onSettle,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      ),
    );
  }
}
