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
      // Data is now streamed via AdminViewModel listener
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminVM = context.watch<AdminViewModel>();
    
    // Support both 'rejected' and legacy 'failed' in the Rejected tab
    final transactions = adminVM.transactions.where((t) {
      if (_filterStatus == 'all') return true;
      if (_filterStatus == 'rejected') {
        return t.status == 'rejected' || t.status == 'failed';
      }
      return t.status == _filterStatus;
    }).toList();

    final filterBar = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: ['pending', 'confirmed', 'rejected', 'all'].map((status) {
          final isSelected = _filterStatus == status;
          final colors = AdminTheme.statusColors(
            status == 'all' ? 'active' : status,
          );
          
          String label = status.toUpperCase();
          if (status == 'rejected') label = 'REJECTED/FINAL';

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                label,
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

    final body = adminVM.isLoading && adminVM.transactions.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : transactions.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: AdminColors.textGrey.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text(
                        'No $_filterStatus transactions found.',
                        style: AdminTheme.mutedStyle(),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
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
        title: 'Payment Verification Queue',
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
    final isRejected = tx.status == 'rejected' || tx.status == 'failed';

    return AdminCard(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                      : Icons.account_balance_wallet,
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
                    Row(
                      children: [
                        Text(
                          tx.type.toUpperCase(),
                          style: AdminTheme.mutedStyle(size: 10),
                        ),
                        if (tx.payerRole.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text('•', style: AdminTheme.mutedStyle(size: 10)),
                          const SizedBox(width: 4),
                          Text(
                            tx.payerRole.toUpperCase(),
                            style: AdminTheme.mutedStyle(size: 10),
                          ),
                        ],
                      ],
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
          
          if (tx.screenshotUrl != null && tx.screenshotUrl!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Payment Proof:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminColors.textGrey)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _showFullImage(context, tx.screenshotUrl!),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AdminColors.border),
                  image: DecorationImage(
                    image: NetworkImage(tx.screenshotUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],

          if (isRejected && tx.rejectionReason != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminColors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AdminColors.red.withValues(alpha: 0.1)),
              ),
              child: Text(
                'Rejection Reason: ${tx.rejectionReason}',
                style: const TextStyle(fontSize: 12, color: AdminColors.red, fontWeight: FontWeight.w500),
              ),
            ),
          ],

          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tx.date != null
                    ? DateFormat('MMM dd, yyyy • HH:mm').format(tx.date!)
                    : 'Unknown Date',
                style: AdminTheme.mutedStyle(size: 11),
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
                    onPressed: () => _showRejectDialog(context, tx.id, vm),
                    style: AdminTheme.destructiveButtonStyle(height: 46),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirmApproval(context, tx, vm),
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

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(child: Image.network(url)),
            Positioned(
              top: 10, right: 10,
              child: IconButton(
                icon: const CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.close, color: Colors.white)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmApproval(BuildContext context, PlatformTransaction tx, AdminViewModel vm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment?'),
        content: Text('Confirming this payment will ${tx.type == 'subscription' ? 'activate the company subscription' : 'settle the supplier commission'} for Rs ${tx.amount.toStringAsFixed(0)}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('CONFIRM', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirmed == true) {
      await vm.markTransaction(tx.id, 'confirmed');
    }
  }

  Future<void> _showRejectDialog(BuildContext context, String transactionId, AdminViewModel vm) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Payment Proof'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection. This will be shown to the user.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Transaction ID not found or screenshot blurry',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.red),
            child: const Text('REJECT PAYMENT'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await vm.markTransaction(transactionId, 'rejected', reason: controller.text.trim());
    }
  }
}
