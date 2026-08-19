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

          final unsettledTransactions = viewModel.transactions.where((t) => t.isUnsettled).toList();
          final unsettledCommission = unsettledTransactions.fold<double>(0, (sum, t) => sum + t.commissionAmount);

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Month selection and other cards...
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _goToPreviousMonth,
                  ),
                  Text(_monthLabel, style: AppTextStyles.h3),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      color: _isCurrentMonth
                          ? FieldColors.textSecondary.withValues(alpha: 0.35)
                          : null,
                    ),
                    onPressed: _isCurrentMonth ? null : _goToNextMonth,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              if (unsettledCommission > 0)
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
                              Text(CurrencyFormatter.formatPKR(unsettledCommission), style: AppTextStyles.h2.copyWith(color: FieldColors.statusDanger)),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PaymentMethodView(
                                    amount: unsettledCommission,
                                    type: PaymentType.commission,
                                    relatedTransactionIds: unsettledTransactions.map((t) => t.txId).toList(),
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: FieldColors.statusDanger,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('PAY NOW'),
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

              _buildStatsCard(
                'Total Gross Earnings',
                CurrencyFormatter.formatPKR(viewModel.totalEarnings),
                Colors.white,
                FieldColors.textPrimary,
              ),
              const SizedBox(height: 12),
              _buildStatsCard(
                'Net Earnings (98%)',
                CurrencyFormatter.formatPKR(viewModel.netEarnings),
                FieldColors.primaryNavy,
                Colors.white,
              ),
              const SizedBox(height: 12),
              _buildStatsCard(
                'Commission Owed (2%)',
                CurrencyFormatter.formatPKR(unsettledCommission),
                Colors.white,
                FieldColors.textPrimary,
              ),
              const SizedBox(height: 12),
              _buildStatsCard(
                'Completed Orders',
                '${viewModel.completedThisMonth} orders',
                Colors.white,
                FieldColors.textPrimary,
              ),
              const SizedBox(height: 32),
              Text('Monthly Performance', style: AppTextStyles.h3),
              const SizedBox(height: 16),
              if (viewModel.monthlyEarnings.isEmpty)
                const SupplierEmptyState(
                  icon: Icons.bar_chart_outlined,
                  title: 'No monthly data yet',
                  subtitle:
                      'Monthly performance charts will appear as you complete orders',
                )
              else
                ...viewModel.monthlyEarnings.map(_buildMonthlyCard),
              const SizedBox(height: 32),
              Text('Recent Transactions', style: AppTextStyles.h3),
              const SizedBox(height: 16),
              if (viewModel.transactions.isEmpty)
                SupplierEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No transactions yet',
                  subtitle:
                      'Transactions for $_monthLabel will appear here after orders are confirmed',
                )
              else
                ...viewModel.transactions.map(_buildTransactionItem),
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
