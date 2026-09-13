import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/payment_proof_model.dart';
import '../../models/transaction_model.dart';
import '../../theme/admin_theme.dart';
import '../../widgets/admin/admin_widgets.dart';

class AdminPaymentProofsView extends StatelessWidget {
  const AdminPaymentProofsView({super.key});

  static const double _amountMismatchThreshold = 0.95;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.screenBg,
      appBar: const AdminAppBar(title: 'Payment Verification Queue'),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('payment_proofs')
            .where('type', isEqualTo: 'subscription') // Only show CEO subscriptions
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
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
                    child: const Icon(Icons.payments_rounded, size: 64, color: AdminColors.textGrey),
                  ),
                  const SizedBox(height: 16),
                  Text('No payments to verify', style: AdminTheme.titleStyle(size: 18).copyWith(color: AdminColors.textGrey)),
                  Text('Subscription requests will appear here', style: AdminTheme.mutedStyle()),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final proof = PaymentProofModel.fromMap(
                docs[index].id, 
                docs[index].data() as Map<String, dynamic>
              );
              
              final bool isRejected = proof.status == 'rejected';
              final bool isPending = proof.status == 'pending_review' || proof.status == 'pending';

              return AdminCard(
                margin: const EdgeInsets.only(bottom: 16),
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(proof.status).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getStatusIcon(proof.status), color: _getStatusColor(proof.status), size: 20),
                  ),
                  title: Text(proof.payerName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AdminColors.navy)),
                  subtitle: Text(
                    '${proof.payerRole.toUpperCase()} • Rs. ${proof.amountExpected} • ${proof.method.toUpperCase()}',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, color: AdminColors.textGrey),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow(Icons.category_rounded, 'Type:', proof.type.toUpperCase()),
                          _infoRow(Icons.confirmation_number_rounded, 'Transaction ID:', proof.transactionIdDetected ?? 'N/A'),
                          _infoRow(Icons.payments_rounded, 'Expected Amount:', 'Rs. ${proof.amountExpected}'),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.image_search_rounded, size: 16, color: AdminColors.navy),
                              const SizedBox(width: 8),
                              Text('RECEIPT VERIFICATION', style: AdminTheme.sectionHeaderStyle()),
                            ],
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () => _showLargeImage(context, proof.screenshotUrl),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AdminColors.border),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Image.network(
                                      proof.screenshotUrl,
                                      height: 250,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                    Container(
                                      margin: const EdgeInsets.all(8),
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (isPending)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _rejectDialog(context, proof.id),
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    label: const Text('REJECT'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AdminColors.red,
                                      side: const BorderSide(color: AdminColors.red),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _approvePayment(context, proof),
                                    icon: const Icon(Icons.check_rounded, size: 18),
                                    label: const Text('CONFIRM'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AdminColors.green,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else if (isRejected)
                             Container(
                               width: double.infinity,
                               padding: const EdgeInsets.all(12),
                               decoration: BoxDecoration(
                                 color: AdminColors.red.withValues(alpha: 0.05), 
                                 borderRadius: BorderRadius.circular(10),
                                 border: Border.all(color: AdminColors.red.withValues(alpha: 0.1)),
                               ),
                               child: Row(
                                 children: [
                                   const Icon(Icons.info_outline_rounded, color: AdminColors.red, size: 16),
                                   const SizedBox(width: 8),
                                   Expanded(child: Text('Rejected: ${proof.adminNotes ?? "No reason provided"}', style: GoogleFonts.plusJakartaSans(color: AdminColors.red, fontSize: 12, fontWeight: FontWeight.w600))),
                                 ],
                               ),
                             )
                          else
                             Center(
                               child: Row(
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 children: [
                                   const Icon(Icons.verified_rounded, color: AdminColors.green, size: 14),
                                   const SizedBox(width: 6),
                                   Text('Confirmed on ${DateFormat('MMM dd, yyyy').format(proof.confirmedAt ?? proof.createdAt)}', style: GoogleFonts.plusJakartaSans(color: AdminColors.textGrey, fontSize: 12, fontWeight: FontWeight.w600)),
                                 ],
                               ),
                             ),
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'approved' || status == 'confirmed' || status == 'settled') return AdminColors.green;
    if (status == 'rejected') return AdminColors.red;
    return AdminColors.amber;
  }

  IconData _getStatusIcon(String status) {
    if (status == 'approved' || status == 'confirmed' || status == 'settled') return Icons.check_circle_rounded;
    if (status == 'rejected') return Icons.cancel_rounded;
    return Icons.pending_rounded;
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 14, color: AdminColors.textGrey),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.plusJakartaSans(color: AdminColors.textGrey, fontSize: 13, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: AdminColors.navy)),
      ],
    ),
  );

  void _showLargeImage(BuildContext context, String url) {
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
                  const Text('Payment Proof', style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<TransactionModel>> _loadUnsettledCommissionTransactions(
    List<String> txIds,
  ) async {
    final unsettled = <TransactionModel>[];
    for (final id in txIds) {
      final doc = await FirebaseFirestore.instance
          .collection('transactions')
          .doc(id)
          .get();
      if (!doc.exists || doc.data() == null) continue;
      final tx = TransactionModel.fromMap(doc.id, doc.data()!);
      if (tx.isUnsettled) unsettled.add(tx);
    }
    return unsettled;
  }

  Future<bool> _confirmAmountMismatch(
    BuildContext context, {
    required double detectedAmount,
    required double expectedTotal,
  }) async {
    final currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: AdminColors.amber),
            const SizedBox(width: 10),
            const Text('Amount Mismatch'),
          ],
        ),
        content: Text(
          'The detected payment amount (${currency.format(detectedAmount)}) is '
          'less than the expected total '
          '(${currency.format(expectedTotal)}).\n\n'
          'Proceed with confirmation anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('PROCEED'),
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.amber),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _approvePayment(BuildContext context, PaymentProofModel proof) async {
    final batch = FirebaseFirestore.instance.batch();
    final String targetStatus = proof.type == 'commission' ? 'settled' : 'confirmed';

    if (proof.type == 'commission') {
      final txIds = proof.relatedTransactions ?? [];
      if (txIds.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('Error: No linked commission records.'),
              backgroundColor: AdminColors.red,
            ),
          );
        }
        return;
      }

      final unsettledTxs = await _loadUnsettledCommissionTransactions(txIds);
      if (unsettledTxs.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text('All linked records are already settled.'),
              backgroundColor: AdminColors.red,
            ),
          );
        }
        return;
      }

      final expectedTotal = unsettledTxs.fold<double>(0.0, (total, tx) => total + tx.commissionAmount);
      final detectedAmount = proof.amountDetected ?? proof.amount;

      if (detectedAmount < expectedTotal * _amountMismatchThreshold) {
        if (!context.mounted) return;
        final proceed = await _confirmAmountMismatch(context, detectedAmount: detectedAmount, expectedTotal: expectedTotal);
        if (!proceed) return;
      }

      batch.update(FirebaseFirestore.instance.collection('payment_proofs').doc(proof.id), {
        'status': targetStatus,
        'confirmedAt': FieldValue.serverTimestamp(),
      });

      for (final tx in unsettledTxs) {
        batch.update(FirebaseFirestore.instance.collection('transactions').doc(tx.txId), {
          'status': 'settled',
          'settledAt': FieldValue.serverTimestamp(),
        });
      }
    } else {
       batch.update(FirebaseFirestore.instance.collection('payment_proofs').doc(proof.id), {
        'status': targetStatus,
        'confirmedAt': FieldValue.serverTimestamp(),
      });

      if (proof.type == 'subscription') {
        batch.set(FirebaseFirestore.instance.collection('subscriptions').doc(proof.payerId), {
          'plan': proof.planKey,
          'status': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
        }, SetOptions(merge: true));
      }
    }

    try {
      await batch.commit();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AdminColors.green,
          content: Text(proof.type == 'commission' ? 'Payment Settled Successfully!' : 'Subscription Confirmed!')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text('Error: $e'), backgroundColor: AdminColors.red));
      }
    }
  }

  Future<void> _rejectDialog(BuildContext context, String docId) async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: AdminColors.red),
            const SizedBox(width: 10),
            const Text('Reject Payment Proof'),
          ],
        ),
        content: TextField(
          controller: controller, 
          maxLines: 3,
          decoration: AdminTheme.inputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'e.g. Invalid screenshot, incorrect amount...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton.icon(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await FirebaseFirestore.instance.collection('payment_proofs').doc(docId).update({
                'status': 'rejected',
                'adminNotes': controller.text.trim(),
              });
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('CONFIRM REJECTION'),
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.red),
          )
        ],
      ),
    );
  }
}
