import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/payment_proof_model.dart';
import '../../theme/admin_theme.dart';
import '../../widgets/admin/admin_widgets.dart';

class AdminPaymentProofsView extends StatelessWidget {
  const AdminPaymentProofsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AdminAppBar(title: 'Payment Verification Queue'),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('payment_proofs')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No payment proofs to verify.'));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final proof = PaymentProofModel.fromMap(
                docs[index].id, 
                docs[index].data() as Map<String, dynamic>
              );
              
              final bool isApproved = proof.status == 'approved';
              final bool isRejected = proof.status == 'rejected';
              final bool isPending = proof.status == 'pending_review';

              return AdminCard(
                margin: const EdgeInsets.only(bottom: 16),
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(proof.status).withValues(alpha: 0.1),
                    child: Icon(_getStatusIcon(proof.status), color: _getStatusColor(proof.status), size: 20),
                  ),
                  title: Text(proof.payerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${proof.payerRole.toUpperCase()} • Rs. ${proof.amountExpected} • ${proof.method.toUpperCase()}',
                    style: const TextStyle(fontSize: 12, color: AdminColors.textGrey),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow('Type:', proof.type.toUpperCase()),
                          _infoRow('Transaction ID:', proof.transactionIdDetected),
                          _infoRow('Detected Amount:', 'Rs. ${proof.amountDetected}'),
                          _infoRow('AI Verified:', proof.isAiVerified ? '✅ YES' : '❌ NO'),
                          const SizedBox(height: 16),
                          const Text('Receipt Screenshot:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _showLargeImage(context, proof.screenshotUrl),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                proof.screenshotUrl,
                                height: 250,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (isPending)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _rejectDialog(context, proof.id),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AdminColors.red,
                                      side: const BorderSide(color: AdminColors.red),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: const Text('REJECT'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => _approvePayment(context, proof),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AdminColors.green,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      elevation: 0,
                                    ),
                                    child: const Text('APPROVE'),
                                  ),
                                ),
                              ],
                            )
                          else if (isRejected)
                             Container(
                               width: double.infinity,
                               padding: const EdgeInsets.all(12),
                               decoration: BoxDecoration(color: AdminColors.red.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                               child: Text('Rejected: ${proof.adminNotes ?? "No reason provided"}', style: const TextStyle(color: AdminColors.red, fontSize: 12)),
                             )
                          else
                             Center(child: Text('Approved on ${DateFormat('MMM dd, hh:mm a').format(proof.createdAt)}', style: const TextStyle(color: AdminColors.textGrey, fontSize: 12))),
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
    if (status == 'approved') return AdminColors.green;
    if (status == 'rejected') return AdminColors.red;
    return AdminColors.amber;
  }

  IconData _getStatusIcon(String status) {
    if (status == 'approved') return Icons.check_circle;
    if (status == 'rejected') return Icons.cancel;
    return Icons.pending;
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AdminColors.textGrey, fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    ),
  );

  void _showLargeImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InteractiveViewer(child: Image.network(url)),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
          ],
        ),
      ),
    );
  }

  Future<void> _approvePayment(BuildContext context, PaymentProofModel proof) async {
    final batch = FirebaseFirestore.instance.batch();
    
    // 1. Update Proof Status
    batch.update(FirebaseFirestore.instance.collection('payment_proofs').doc(proof.id), {
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
    });

    // 2. Handle Logic based on Type
    if (proof.type == 'subscription') {
      // Activate Subscription for CEO
      batch.set(FirebaseFirestore.instance.collection('subscriptions').doc(proof.payerId), {
        'plan': proof.planKey,
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      }, SetOptions(merge: true));
    } else {
      // Settle Transactions for Supplier
      final List<String> txIds = proof.relatedTransactions ?? [];
      for (var id in txIds) {
        batch.update(FirebaseFirestore.instance.collection('transactions').doc(id), {
          'status': 'settled',
          'settledAt': FieldValue.serverTimestamp(),
        });
      }
    }

    try {
      await batch.commit();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Approved & Access Granted!')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AdminColors.red));
      }
    }
  }

  Future<void> _rejectDialog(BuildContext context, String docId) async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Payment Proof'),
        content: TextField(
          controller: controller, 
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter reason for rejection...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await FirebaseFirestore.instance.collection('payment_proofs').doc(docId).update({
                'status': 'rejected',
                'adminNotes': controller.text.trim(),
              });
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.red),
            child: const Text('REJECT'),
          )
        ],
      ),
    );
  }
}
