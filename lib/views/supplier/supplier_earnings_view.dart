import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme/supplier_theme.dart';
import '../../models/transaction_model.dart';
import '../../models/payment_proof_model.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: const SupplierAppBar(title: 'Earnings & Commissions'),
      bottomNavigationBar: const SupplierNavBar(currentIndex: 4),
      body: Consumer<SupplierViewModel>(
        builder: (context, viewModel, child) {
          final commissionOwed = viewModel.commissionOwed;
          final totalPaid = viewModel.totalCommissionPaid;
          final grossSales = viewModel.grossSalesForMonth(_monthKey);
          final netEarnings = viewModel.netEarningsForMonth(_monthKey);
          final recentTransactions = viewModel.transactions;
          final paymentHistory = viewModel.paymentHistory;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Commission Owed Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: commissionOwed > 0 ? FieldColors.statusDanger : FieldColors.statusSuccess,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    Text(
                      commissionOwed > 0 ? 'TOTAL COMMISSION OWED' : 'COMMISSION FULLY SETTLED',
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.formatPKR(commissionOwed),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)
                    ),
                    if (commissionOwed > 0) ...[
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommissionPaymentView())),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: FieldColors.statusDanger,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('PAY NOW', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.white70, size: 16),
                          SizedBox(width: 8),
                          Text('All payments are up to date', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Monthly Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Summary: $_monthLabel', style: AppTextStyles.h3),
                  TextButton(
                    onPressed: () => _selectMonth(context),
                    child: const Text('Change Month'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStatsRow('Gross Sales', CurrencyFormatter.formatPKR(grossSales)),
              _buildStatsRow('Net (After 2% Comm.)', CurrencyFormatter.formatPKR(netEarnings)),
              _buildStatsRow('Total Commission Paid', CurrencyFormatter.formatPKR(totalPaid), isSettled: true),
              
              const SizedBox(height: 32),
              
              // Tabs for History
              DefaultTabController(
                length: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: FieldColors.primaryNavy,
                      indicatorColor: FieldColors.primaryNavy,
                      tabs: const [Tab(text: 'Orders & Comm.'), Tab(text: 'Payment History')],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 400,
                      child: TabBarView(
                        children: [
                          _buildOrderList(recentTransactions),
                          _buildPaymentList(paymentHistory),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(String label, String value, {bool isSettled = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body.copyWith(color: FieldColors.textSecondary)),
          Text(
            value, 
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.bold,
              color: isSettled ? FieldColors.statusSuccess : null,
            )
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<TransactionModel> txs) {
    if (txs.isEmpty) return const Center(child: Text('No order commissions this month.'));
    return ListView.builder(
      itemCount: txs.length,
      itemBuilder: (context, i) {
        final tx = txs[i];
        final settled = tx.status == 'settled' || tx.status == 'confirmed';
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: FieldColors.borderSubtle),
          ),
          child: ListTile(
            title: Text('Order #${tx.orderId.substring(tx.orderId.length - 6).toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Row(
              children: [
                Text(DateFormat('MMM dd').format(tx.createdAt)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: settled ? FieldColors.statusSuccess.withValues(alpha: 0.1) : FieldColors.statusDanger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    settled ? 'SETTLED' : 'UNSETTLED',
                    style: TextStyle(
                      fontSize: 9, 
                      fontWeight: FontWeight.bold,
                      color: settled ? FieldColors.statusSuccess : FieldColors.statusDanger,
                    ),
                  ),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  CurrencyFormatter.formatPKR(tx.commissionAmount), 
                  style: TextStyle(
                    color: settled ? FieldColors.statusSuccess : FieldColors.statusDanger, 
                    fontWeight: FontWeight.bold
                  )
                ),
                const Text('Commission', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentList(List<PaymentProofModel> payments) {
    if (payments.isEmpty) return const Center(child: Text('No payment history found.'));
    return ListView.builder(
      itemCount: payments.length,
      itemBuilder: (context, i) {
        final p = payments[i];
        final isSettled = p.status == 'settled' || p.status == 'confirmed' || p.status == 'approved';
        final isRejected = p.status == 'rejected';
        final isPending = p.status == 'pending';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: FieldColors.borderSubtle),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSettled ? FieldColors.statusSuccess.withValues(alpha: 0.1) : (isRejected ? Colors.red.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1)),
              child: Icon(
                isSettled ? Icons.check_circle : (isRejected ? Icons.cancel : Icons.hourglass_top), 
                color: isSettled ? FieldColors.statusSuccess : (isRejected ? Colors.red : Colors.orange),
                size: 20,
              ),
            ),
            title: Text('Payment: ${CurrencyFormatter.formatPKR(p.amount)}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${DateFormat('MMM dd, yyyy').format(p.createdAt)} • ${p.status.toUpperCase()}'),
            trailing: const Icon(Icons.chevron_right, size: 16, color: FieldColors.textMuted),
          ),
        );
      },
    );
  }

  void _selectMonth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _currentMonth,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _currentMonth = picked);
      context.read<SupplierViewModel>().changeMonth(DateFormat('yyyy-MM').format(picked));
    }
  }
}
