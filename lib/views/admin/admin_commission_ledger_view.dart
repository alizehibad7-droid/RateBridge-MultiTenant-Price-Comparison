import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme/admin_theme.dart';
import '../../models/transaction_model.dart';
import '../../models/payment_proof_model.dart';
import '../../repositories/transaction_repository.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../widgets/admin/admin_widgets.dart';

class AdminCommissionLedgerView extends StatefulWidget {
  const AdminCommissionLedgerView({super.key});

  @override
  State<AdminCommissionLedgerView> createState() => _AdminCommissionLedgerViewState();
}

class _AdminCommissionLedgerViewState extends State<AdminCommissionLedgerView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminViewModel>().loadPaymentQueue();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminVM = context.watch<AdminViewModel>();
    final repo = context.read<TransactionRepository>();
    
    final pendingCommissionPayments = adminVM.pendingPayments.where((p) => p.type == 'commission').toList();
    final settledCommissionPayments = adminVM.confirmedPayments.where((p) => p.type == 'commission').toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AdminColors.navy,
            unselectedLabelColor: AdminColors.textGrey,
            indicatorColor: AdminColors.navy,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: const [
              Tab(
                icon: Icon(Icons.account_balance_wallet_rounded, size: 20),
                text: 'Active Ledger',
              ),
              Tab(
                icon: Icon(Icons.history_rounded, size: 20),
                text: 'Settled History',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildLedgerTab(repo, adminVM, pendingCommissionPayments),
              _buildSettledTab(settledCommissionPayments, adminVM),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLedgerTab(TransactionRepository repo, AdminViewModel adminVM, List<PaymentProofModel> pendingComms) {
    return StreamBuilder<CommissionLedgerSnapshot>(
      stream: repo.watchCommissionLedger(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final ledger = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () => adminVM.loadPaymentQueue(),
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
        
              if (pendingComms.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.pending_actions_rounded, color: AdminColors.navy, size: 18),
                    const SizedBox(width: 8),
                    const AdminSectionLabel('Awaiting Verification'),
                  ],
                ),
                const SizedBox(height: 12),
                ...pendingComms.map((p) => _PendingPaymentCard(payment: p, vm: adminVM)),
                const SizedBox(height: 28),
              ],
        
              Row(
                children: [
                  const Icon(Icons.store_rounded, color: AdminColors.navy, size: 18),
                  const SizedBox(width: 8),
                  const AdminSectionLabel('Supplier Balances'),
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

  Widget _buildSettledTab(List<PaymentProofModel> settledComms, AdminViewModel adminVM) {
    if (adminVM.isLoading && settledComms.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (settledComms.isEmpty) {
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
              child: const Icon(Icons.history_rounded, size: 64, color: AdminColors.textGrey),
            ),
            const SizedBox(height: 24),
            Text('No settled history', style: AdminTheme.titleStyle(size: 18).copyWith(color: AdminColors.textGrey)),
            const SizedBox(height: 8),
            Text('Cleared commission records will appear here', style: AdminTheme.mutedStyle()),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => adminVM.loadPaymentQueue(),
      color: AdminColors.amber,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: settledComms.length,
        itemBuilder: (context, index) {
          return _PendingPaymentCard(payment: settledComms[index], vm: adminVM, isHistory: true);
        },
      ),
    );
  }
}

class _PendingPaymentCard extends StatelessWidget {
  final PaymentProofModel payment;
  final AdminViewModel vm;
  final bool isHistory;

  const _PendingPaymentCard({
    required this.payment, 
    required this.vm, 
    this.isHistory = false
  });

  @override
  Widget build(BuildContext context) {
    final isSettled = payment.status == 'settled';

    return AdminCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isHistory ? AdminColors.green : AdminColors.amber).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isHistory ? Icons.verified_rounded : Icons.payments_rounded, 
                color: isHistory ? AdminColors.green : AdminColors.amber,
                size: 24,
              ),
            ),
            title: Text(payment.payerName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AdminColors.navy)),
            subtitle: Row(
              children: [
                Icon(isHistory ? Icons.event_available_rounded : Icons.access_time_rounded, size: 12, color: AdminColors.textGrey),
                const SizedBox(width: 4),
                Text(
                  isHistory 
                    ? 'Settled: ${payment.confirmedAt != null ? DateFormat('MMM dd').format(payment.confirmedAt!) : 'N/A'}'
                    : 'Submitted: ${DateFormat('MMM dd, HH:mm').format(payment.createdAt)}',
                  style: AdminTheme.mutedStyle(size: 11),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Rs ${payment.amount.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 18, color: AdminColors.navy)),
                if (isHistory)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isSettled ? AdminColors.purple : AdminColors.green).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isSettled ? 'SETTLED' : 'CONFIRMED',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isSettled ? AdminColors.purple : AdminColors.green,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),
          Row(
            children: [
              const Icon(Icons.image_search_rounded, size: 14, color: AdminColors.textGrey),
              const SizedBox(width: 6),
              const Text('PAYMENT PROOF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AdminColors.textGrey, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _showFullImage(context, payment.screenshotUrl),
            child: Container(
              height: 140, width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminColors.border),
                image: DecorationImage(image: NetworkImage(payment.screenshotUrl), fit: BoxFit.cover),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black12,
                ),
                child: const Center(child: Icon(Icons.zoom_in_rounded, color: Colors.white, size: 32)),
              ),
            ),
          ),
          
          if (!isHistory) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: vm.isLoading ? null : () => _showRejectDialog(context), 
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('REJECT'),
                    style: AdminTheme.destructiveButtonStyle(height: 44),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: vm.isLoading ? null : () => _confirmSettlement(context), 
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('SETTLE'),
                    style: AdminTheme.primaryButtonStyle(height: 44).copyWith(backgroundColor: WidgetStateProperty.all(AdminColors.green)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmSettlement(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.verified_rounded, color: AdminColors.green),
            const SizedBox(width: 10),
            const Text('Confirm Settlement'),
          ],
        ),
        content: Text('Mark Rs ${payment.amount.toStringAsFixed(0)} commission payment from ${payment.payerName} as settled? This will clear their outstanding balance.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true), 
            icon: const Icon(Icons.check_rounded),
            label: const Text('CONFIRM'),
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.green),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await vm.confirmPayment(payment);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Payment marked as settled successfully.'))
        );
      }
    }
  }

  Future<void> _showRejectDialog(BuildContext context) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: AdminColors.red),
            const SizedBox(width: 10),
            const Text('Reject Payment Proof'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Provide a reason for rejection. This will be shown to the supplier.', style: TextStyle(fontSize: 13, color: AdminColors.textGrey)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: AdminTheme.inputDecoration(
                hintText: 'e.g. Screenshot is unreadable, amount mismatch...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          ElevatedButton.icon(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            icon: const Icon(Icons.close_rounded),
            label: const Text('REJECT PROOF'),
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.red, foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await vm.rejectPayment(payment, controller.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Payment proof rejected.'))
        );
      }
    }
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(context: context, builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
      )));
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
