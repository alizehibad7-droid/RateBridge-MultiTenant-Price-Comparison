// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../constants/app_colors.dart';
import '../../utils/currency_formatter.dart';
import 'package:intl/intl.dart';

class SupplierEarningsView extends StatefulWidget {
  const SupplierEarningsView({super.key});

  @override
  State<SupplierEarningsView> createState() => _SupplierEarningsViewState();
}

class _SupplierEarningsViewState extends State<SupplierEarningsView> {
  String _selectedMonth = DateFormat('MMMM yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierViewModel>().loadEarnings(_selectedMonth);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Earnings', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Consumer<SupplierViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading && viewModel.transactions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Month Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      // Logic to decrement month and call changeMonth
                    },
                  ),
                  Text(_selectedMonth, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      // Logic to increment month and call changeMonth
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Stats Column
              _buildStatsCard('Total Gross Earnings', 'Rs. 52,000', Colors.white, AppColors.textPrimary),
              const SizedBox(height: 12),
              _buildStatsCard('Net Earnings (98%)', 'Rs. 50,960', AppColors.primary, Colors.white),
              const SizedBox(height: 12),
              _buildStatsCard('Pending Payments', 'Rs. 4,500', Colors.white, AppColors.textPrimary),
              const SizedBox(height: 12),
              _buildStatsCard('Completed Payouts', 'Rs. 46,460', Colors.white, AppColors.textPrimary),
              
              const SizedBox(height: 32),
              const Text('Performance Trend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(child: Text('Chart Placeholder', style: TextStyle(color: Colors.grey))),
              ),

              const SizedBox(height: 32),
              const Text('Recent Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              ...viewModel.transactions.map((tx) => _buildTransactionItem(tx)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsCard(String label, String value, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: text.withOpacity(0.7), fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(dynamic tx) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          title: Text('Order #${tx.orderId.substring(tx.orderId.length - 6)}'),
          subtitle: Text(DateFormat('MMM dd, yyyy').format(tx.timestamp)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(CurrencyFormatter.formatPKR(tx.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
              const Text('-2% Comm.', style: TextStyle(color: Colors.red, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
