// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme/supplier_theme.dart';
import '../../models/transaction_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../widgets/supplier/supplier_async_states.dart';
import '../../widgets/supplier_nav_bar.dart';
import '../payment/payment_method_view.dart';
import '../../models/payment_proof_model.dart';

class SupplierEarningsView extends StatefulWidget {
  const SupplierEarningsView({super.key});

  @override
  State<SupplierEarningsView> createState() => _SupplierEarningsViewState();
}

class _SupplierEarningsViewState extends State<SupplierEarningsView> {
  DateTime _currentMonth = DateTime.now();

  String get _monthLabel => DateFormat('MMMM yyyy').format(_currentMonth);

  String get _monthKey => DateFormat('yyyy-MM').format(_currentMonth);

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _currentMonth.month == now.month && _currentMonth.year == now.year;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierViewModel>().loadEarnings(_monthKey);
    });
  }

  void _goToPreviousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    context.read<SupplierViewModel>().changeMonth(_monthKey);
  }

  void _goToNextMonth() {
    if (_isCurrentMonth) return;
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    context.read<SupplierViewModel>().changeMonth(_monthKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: const SupplierAppBar(title: 'Earnings'),
      bottomNavigationBar: const SupplierNavBar(currentIndex: 4),
      body: Consumer<SupplierViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading && viewModel.transactions.isEmpty) {
            return const SupplierListSkeleton(itemCount: 5, itemHeight: 72);
          }

          // Global calculation for Owed Commission
          // FIX: guard against null values from the ViewModel that may not
          // be populated yet on first build — this was the source of the
          // "Unexpected null value" crash in this ListView.
          final globalCommission = viewModel.globalUnsettledCommission ?? 0;
          final globalUnsettledTxIds = (viewModel.allUnsettledTransactions ?? [])
              .map((t) => t.txId)
              .toList();
          final lifetimeGross = viewModel.lifetimeGrossEarnings ?? 0;
          final lifetimeNet = viewModel.lifetimeNetEarnings ?? 0;
          final transactionsList = viewModel.transactions ?? [];
          final monthlyEarningsList = viewModel.monthlyEarnings ?? [];

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (globalCommission > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: FieldColors.statusDanger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: FieldColors.statusDanger.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Unsettled Commission', style: TextStyle(color: FieldColors.statusDanger, fontWeight: FontWeight.bold)),
                              Text(CurrencyFormatter.formatPKR(globalCommission), style: AppTextStyles.h2.copyWith(color: FieldColors.statusDanger)),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PaymentMethodView(
                                    amount: globalCommission,
                                    type: PaymentType.commission,
                                    relatedTransactionIds: globalUnsettledTxIds,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FieldColors.statusDanger,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              minimumSize: Size.zero,
                            ),
                            child: const Text('PAY NOW', style: TextStyle(fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Please clear your outstanding balance to avoid account suspension.',
                        style: TextStyle(fontSize: 11, color: FieldColors.statusDanger),
                      ),
                    ],
                  ),
                ),

              const Text('Performance Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: FieldColors.primaryNavy)),
              const SizedBox(height: 16),

              _buildStatsCard(
                'Lifetime Gross Earnings',
                CurrencyFormatter.formatPKR(lifetimeGross),
                Colors.white,
                FieldColors.textPrimary,
              ),
              const SizedBox(height: 12),
              _buildStatsCard(
                'Lifetime Net Earnings',
                CurrencyFormatter.formatPKR(lifetimeNet),
                FieldColors.primaryNavy,
                Colors.white,
              ),
              const SizedBox(height: 12),
              _buildStatsCard(
                'Total Owed (Unsettled)',
                CurrencyFormatter.formatPKR(globalCommission),
                Colors.white,
                FieldColors.statusDanger,
              ),

              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Monthly Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: FieldColors.primaryNavy)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: FieldColors.borderSubtle)),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _goToPreviousMonth,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(DateFormat('MMM yy').format(_currentMonth), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right, size: 20, color: _isCurrentMonth ? Colors.grey : null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _isCurrentMonth ? null : _goToNextMonth,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (transactionsList.isEmpty)
                SupplierEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No transactions yet',
                  subtitle: 'Transactions for $_monthLabel will appear here after orders are confirmed',
                )
              else
                ...transactionsList.map(_buildTransactionItem),

              const SizedBox(height: 32),
              Text('Earnings History', style: AppTextStyles.h3),
              const SizedBox(height: 16),
              if (monthlyEarningsList.isEmpty)
                const SupplierEmptyState(
                  icon: Icons.bar_chart_outlined,
                  title: 'No history available',
                  subtitle: 'Historical data will appear as you complete more orders',
                )
              else
                ...monthlyEarningsList.map(_buildMonthlyCard),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsCard(
      String label,
      String value,
      Color bg,
      Color text,
      ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: FieldColors.borderSubtle),
        boxShadow: [
          BoxConstraints().maxWidth > 0 ? BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)) : const BoxShadow(),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(
                color: text.withValues(alpha: 0.75),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: AppTextStyles.h3.copyWith(color: text),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyCard(MonthlyEarning earning) {
    final monthDate = DateTime.tryParse('${earning.month}-01');
    final monthLabel = monthDate != null
        ? DateFormat('MMM yyyy').format(monthDate)
        : earning.month;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: SupplierTheme.cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(monthLabel, style: AppTextStyles.h3),
                const SizedBox(height: 4),
                Text(
                  '${earning.orderCount} ${earning.orderCount == 1 ? 'order' : 'orders'}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.formatPKR(earning.net),
                style: AppTextStyles.h3.copyWith(color: FieldColors.statusSuccess),
              ),
              const SizedBox(height: 2),
              Text(
                'Net earnings',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(TransactionModel tx) {
    final orderSuffix = tx.orderId.length >= 6
        ? tx.orderId.substring(tx.orderId.length - 6)
        : tx.orderId;
    final statusLabel = tx.status.isNotEmpty
        ? tx.status[0].toUpperCase() + tx.status.substring(1).toLowerCase()
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: FieldColors.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order #$orderSuffix', style: AppTextStyles.body),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM dd, yyyy').format(tx.createdAt),
                      style: AppTextStyles.caption,
                    ),
                    if (statusLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        statusLabel,
                        style: AppTextStyles.caption.copyWith(
                          color: tx.isUnsettled
                              ? FieldColors.statusWarning
                              : FieldColors.statusSuccess,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    CurrencyFormatter.formatPKR(tx.supplierEarning),
                    style: AppTextStyles.h3.copyWith(
                      color: FieldColors.statusSuccess,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Gross ${CurrencyFormatter.formatPKR(tx.totalAmount)}',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                    textAlign: TextAlign.end,
                  ),
                  Text(
                    '-${(tx.commissionRate * 100).toStringAsFixed(0)}% comm.',
                    style: const TextStyle(color: FieldColors.statusDanger, fontSize: 10),
                    textAlign: TextAlign.end,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}