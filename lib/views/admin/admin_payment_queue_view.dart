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
  String _filterStatus = 'pending';

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
    final transactions = adminVM.transactions
        .where((t) => _filterStatus == 'all' || t.status == _filterStatus)
        .toList();

    final filterBar = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: ['pending', 'confirmed', 'failed', 'all'].map((status) {
          final isSelected = _filterStatus == status;
          final colors = AdminTheme.statusColors(
            status == 'all' ? 'active' : status,
          );
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                status.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? colors.fg : AdminColors.textGrey,
                ),
              ),
              selected: isSelected,
              selectedColor: colors.bg,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected ? colors.fg : AdminColors.border,
              ),
              onSelected: (_) => setState(() => _filterStatus = status),
            ),
          );
        }).toList(),
      ),
    );

    final body = adminVM.isLoading
        ? const Center(child: CircularProgressIndicator())
        : transactions.isEmpty
            ? Center(
                child: Text(
                  'No transactions found in this category.',
                  style: AdminTheme.mutedStyle(),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final tx = transactions[index];
                  return _buildTransactionCard(tx, adminVM);
                },
              );

    if (widget.embedded) {
      return Column(
        children: [
          filterBar,
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AdminColors.screenBg,
      appBar: AdminAppBar(
        title: 'Financial Reconciliation',
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: filterBar,
        ),
      ),
      body: body,
    );
  }

  Widget _buildTransactionCard(PlatformTransaction tx, AdminViewModel vm) {
    final isPending = tx.status == 'pending';

    return AdminCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AdminColors.navy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  tx.type == 'subscription'
                      ? Icons.workspace_premium
                      : Icons.shopping_cart,
                  color: AdminColors.navy,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.companyName,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AdminColors.navy,
                      ),
                    ),
                    Text(
                      tx.type.toUpperCase(),
                      style: AdminTheme.mutedStyle(size: 10),
                    ),
                  ],
                ),
              ),
              Text(
                'Rs ${tx.amount.toStringAsFixed(0)}',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AdminColors.navy,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tx.date != null
                    ? DateFormat('MMM dd, HH:mm').format(tx.date!)
                    : 'Unknown Date',
                style: AdminTheme.mutedStyle(size: 12),
              ),
              StatusChip(status: tx.status),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => vm.markTransaction(tx.id, 'failed'),
                    style: AdminTheme.destructiveButtonStyle(),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => vm.markTransaction(tx.id, 'confirmed'),
                    style: AdminTheme.primaryButtonStyle(height: 46),
                    child: const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
