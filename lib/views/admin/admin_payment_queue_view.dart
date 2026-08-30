import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../theme/admin_theme.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../widgets/admin/admin_widgets.dart';
import '../../models/payment_proof_model.dart';

class AdminPaymentQueueView extends StatefulWidget {
  final bool embedded;

  const AdminPaymentQueueView({super.key, this.embedded = false});

  @override
  State<AdminPaymentQueueView> createState() => _AdminPaymentQueueViewState();
}

class _AdminPaymentQueueViewState extends State<AdminPaymentQueueView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AdminColors.navy,
            unselectedLabelColor: AdminColors.textGrey,
            indicatorColor: AdminColors.amber,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: const [
              Tab(
                icon: Icon(Icons.pending_rounded, size: 20),
                text: 'Pending Verification',
              ),
              Tab(
                icon: Icon(Icons.history_rounded, size: 20),
                text: 'Payment History',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPaymentList(
                adminVM.pendingPayments.where((p) => p.type == 'subscription').toList(), 
                adminVM, 
                isPending: true
              ),
              _buildPaymentList(adminVM.confirmedPayments, adminVM, isPending: false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentList(List<PaymentProofModel> payments, AdminViewModel vm, {required bool isPending}) {
    if (vm.isLoading && payments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (payments.isEmpty) {
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
              child: Icon(
                isPending ? Icons.fact_check_rounded : Icons.payments_rounded, 
                size: 64, 
                color: AdminColors.textGrey.withValues(alpha: 0.5)
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isPending ? 'No pending verifications' : 'No payment history yet',
              style: AdminTheme.titleStyle(size: 18).copyWith(color: AdminColors.textGrey),
            ),
            const SizedBox(height: 8),
            Text(
              isPending ? 'All subscription payments are up to date' : 'Confirmed payments will appear here',
              style: AdminTheme.mutedStyle(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => vm.loadPaymentQueue(),
      color: AdminColors.amber,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: payments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildPaymentCard(payments[index], vm, isPending);
        },
      ),
    );
  }

  Widget _buildPaymentCard(PaymentProofModel payment, AdminViewModel vm, bool isPending) {
    final isSettled = payment.status == 'settled';
    final isConfirmed = payment.status == 'confirmed' || payment.status == 'approved';

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AdminColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  payment.type == 'subscription' ? Icons.workspace_premium_rounded : Icons.account_balance_wallet_rounded,
                  color: AdminColors.navy,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.payerName,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AdminColors.navy,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AdminColors.amber.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            payment.type.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AdminColors.darkAmber,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '• ${payment.payerRole}',
                          style: AdminTheme.mutedStyle(size: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Rs ${payment.amount.toStringAsFixed(0)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AdminColors.navy,
                    ),
                  ),
                  if (!isPending)
                    StatusChip(status: payment.status),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminColors.screenBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AdminColors.border),
            ),
            child: Column(
              children: [
                if (payment.type == 'subscription')
                  _buildInfoRow(Icons.auto_awesome_rounded, 'Plan', payment.planName ?? 'N/A'),
                _buildInfoRow(Icons.account_balance_rounded, 'Method', payment.method.toUpperCase()),
                _buildInfoRow(Icons.calendar_today_rounded, 'Submitted', DateFormat('MMM dd, yyyy · HH:mm').format(payment.createdAt)),
                if (!isPending && payment.confirmedAt != null)
                  _buildInfoRow(Icons.verified_rounded, isSettled ? 'Settled On' : 'Confirmed On', DateFormat('MMM dd, yyyy').format(payment.confirmedAt!), valueColor: AdminColors.green),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.image_search_rounded, size: 14, color: AdminColors.textGrey),
              const SizedBox(width: 8),
              Text('RECEIPT PROOF', style: AdminTheme.sectionHeaderStyle().copyWith(fontSize: 10, letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _showFullImage(context, payment.screenshotUrl),
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AdminColors.border),
                image: DecorationImage(
                  image: NetworkImage(payment.screenshotUrl),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black12,
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ),

          if (isPending) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(context, payment, vm),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('REJECT'),
                    style: AdminTheme.destructiveButtonStyle(height: 48),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmApproval(context, payment, vm),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('CONFIRM PAYMENT'),
                    style: AdminTheme.primaryButtonStyle(height: 48).copyWith(
                      backgroundColor: WidgetStateProperty.all(AdminColors.green),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AdminColors.textGrey),
          const SizedBox(width: 10),
          Text(label, style: AdminTheme.mutedStyle(size: 13)),
          const Spacer(),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor ?? AdminColors.navy)),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Payment Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            Flexible(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmApproval(BuildContext context, PaymentProofModel payment, AdminViewModel vm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.verified_rounded, color: AdminColors.green),
            const SizedBox(width: 10),
            const Text('Confirm Payment'),
          ],
        ),
        content: Text('Confirming this Rs ${payment.amount.toStringAsFixed(0)} payment will manually activate the ${payment.planName ?? 'subscription'} for ${payment.payerName}.'),
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
            content: Text('Payment confirmed and subscription activated.'))
        );
      }
    }
  }

  Future<void> _showRejectDialog(BuildContext context, PaymentProofModel payment, AdminViewModel vm) async {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Explain why this proof was rejected. The user will see this message.', style: TextStyle(fontSize: 13, color: AdminColors.textGrey)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: AdminTheme.inputDecoration(
                hintText: 'e.g. Transaction ID not found, screenshot is blurred...',
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
}
