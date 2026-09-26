import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/transaction_model.dart';
import '../../theme/supplier_theme.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../widgets/supplier/supplier_async_states.dart';
import '../../widgets/supplier_nav_bar.dart';

import 'commission_payment_view.dart';

class SupplierEarningsView extends StatefulWidget {
  const SupplierEarningsView({super.key});

  @override
  State<SupplierEarningsView> createState() => _SupplierEarningsViewState();
}

class _SupplierEarningsViewState extends State<SupplierEarningsView> {
  DateTime _currentMonth = DateTime.now();

  String get _monthLabel => DateFormat('MMMM yyyy').format(_currentMonth);
  String get _monthKey => DateFormat('yyyy-MM').format(_currentMonth);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierViewModel>().loadEarnings(_monthKey);
    });
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _currentMonth,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _currentMonth = picked);
    context.read<SupplierViewModel>().changeMonth(
      DateFormat('yyyy-MM').format(picked),
    );
  }

  void _openPayCommission() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CommissionPaymentView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: const SupplierAppBar(title: 'Earnings & Commissions'),
      bottomNavigationBar: const SupplierNavBar(currentIndex: 4),
      body: Consumer<SupplierViewModel>(
        builder: (context, vm, _) {
          final commissionOwed = vm.commissionOwed;
          final totalPaid = vm.totalCommissionPaid;
          final grossSales = vm.grossSalesForMonth(_monthKey);
          final netEarnings = vm.netEarningsForMonth(_monthKey);
          final transactions = vm.transactions;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              FieldSpacing.md,
              FieldSpacing.md,
              FieldSpacing.md,
              FieldSpacing.xl,
            ),
            children: [
              _NetEarningsHero(
                netEarnings: netEarnings,
                monthLabel: _monthLabel,
              ),
              const SizedBox(height: FieldSpacing.md),
              _CommissionStatusCard(
                amountOwed: commissionOwed,
                onPay: _openPayCommission,
              ),
              const SizedBox(height: FieldSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Monthly summary',
                      style: AppTextStyles.h3.copyWith(
                        color: FieldColors.primaryNavy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _selectMonth,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(_monthLabel),
                  ),
                ],
              ),
              const SizedBox(height: FieldSpacing.sm),
              _SummaryCard(
                grossSales: grossSales,
                netEarnings: netEarnings,
                totalPaid: totalPaid,
              ),
              const SizedBox(height: FieldSpacing.lg),
              Text(
                'Order Commission History',
                style: AppTextStyles.h3.copyWith(
                  color: FieldColors.primaryNavy,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: FieldSpacing.md),
              ..._orderCards(transactions),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _orderCards(List<TransactionModel> txs) {
    if (txs.isEmpty) {
      return const [
        SizedBox(
          height: 220,
          child: SupplierEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No commissions this month',
            subtitle: 'Order commissions will appear here as sales come in.',
          ),
        ),
      ];
    }
    return [
      for (final tx in txs)
        Padding(
          padding: const EdgeInsets.only(bottom: FieldSpacing.sm),
          child: _OrderCommissionCard(transaction: tx),
        ),
    ];
  }
}

class _NetEarningsHero extends StatelessWidget {
  final double netEarnings;
  final String monthLabel;

  const _NetEarningsHero({
    required this.netEarnings,
    required this.monthLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FieldSpacing.md),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FieldColors.primaryNavy, FieldColors.primaryNavyDark],
        ),
        borderRadius: BorderRadius.all(Radius.circular(FieldRadius.card)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NET EARNINGS · $monthLabel'.toUpperCase(),
            style: AppTextStyles.label.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.formatPKR(netEarnings),
            style: FieldTypography.displayLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'After 2% platform commission',
            style: AppTextStyles.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommissionStatusCard extends StatelessWidget {
  final double amountOwed;
  final VoidCallback onPay;

  const _CommissionStatusCard({
    required this.amountOwed,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final owed = amountOwed > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FieldSpacing.md),
      decoration: SupplierTheme.cardDecoration(
        borderColor: owed
            ? FieldColors.statusDanger.withValues(alpha: 0.35)
            : FieldColors.statusSuccess.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                owed ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                size: 20,
                color: owed ? FieldColors.statusDanger : FieldColors.statusSuccess,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  owed ? 'Commission outstanding' : 'Commission settled',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: FieldColors.primaryNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.formatPKR(amountOwed),
            style: AppTextStyles.h2.copyWith(
              color: owed ? FieldColors.statusDanger : FieldColors.statusSuccess,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            owed
                ? 'Pay outstanding commission to keep listings visible to buyers.'
                : 'All commission payments are up to date.',
            style: AppTextStyles.caption,
          ),
          if (owed) ...[
            const SizedBox(height: FieldSpacing.md),
            FilledButton.icon(
              onPressed: onPay,
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: const Text('Pay commission'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double grossSales;
  final double netEarnings;
  final double totalPaid;

  const _SummaryCard({
    required this.grossSales,
    required this.netEarnings,
    required this.totalPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FieldSpacing.md),
      decoration: SupplierTheme.cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _MiniStat(
              value: CurrencyFormatter.formatPKR(grossSales),
              label: 'Gross sales',
            ),
          ),
          Expanded(
            child: _MiniStat(
              value: CurrencyFormatter.formatPKR(netEarnings),
              label: 'Net payout',
            ),
          ),
          Expanded(
            child: _MiniStat(
              value: CurrencyFormatter.formatPKR(totalPaid),
              label: 'Commission paid',
              valueColor: FieldColors.statusSuccess,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const _MiniStat({
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: valueColor ?? FieldColors.primaryNavy,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    );
  }
}

class _OrderCommissionCard extends StatelessWidget {
  final TransactionModel transaction;

  const _OrderCommissionCard({required this.transaction});

  String get _shortId {
    final id = transaction.orderId;
    if (id.isEmpty) return '—';
    return id.length <= 6 ? id.toUpperCase() : id.substring(id.length - 6).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final settled = transaction.isSettled;
    final status = _chipStyle(
      settled,
      settledLabel: 'Settled',
      pendingLabel: 'Unsettled',
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: SupplierTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: FieldColors.primaryNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: FieldColors.primaryNavy,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #$_shortId',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, yyyy').format(transaction.createdAt),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.formatPKR(transaction.commissionAmount),
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: settled
                      ? FieldColors.statusSuccess
                      : FieldColors.statusDanger,
                ),
              ),
              const SizedBox(height: 4),
              _StatusChip(bg: status.bg, fg: status.fg, label: status.label),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final Color bg;
  final Color fg;
  final String label;

  const _StatusChip({
    required this.bg,
    required this.fg,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

({Color bg, Color fg, String label}) _chipStyle(
  bool positive, {
  required String settledLabel,
  required String pendingLabel,
}) {
  if (positive) {
    return (
      bg: FieldColors.statusSuccess.withValues(alpha: 0.12),
      fg: FieldColors.statusSuccess,
      label: settledLabel,
    );
  }
  return (
    bg: FieldColors.accentAmberSoft,
    fg: FieldColors.statusWarning,
    label: pendingLabel,
  );
}
