import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme/admin_theme.dart';
import '../../models/subscription_model.dart';
import '../../models/subscription_payment_model.dart';
import '../../repositories/subscription_payment_repository.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/admin/admin_widgets.dart';
import 'admin_payment_settings_view.dart';

class AdminSubscriptionPaymentsView extends StatelessWidget {
  final bool embedded;

  const AdminSubscriptionPaymentsView({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<SubscriptionPaymentRepository>();

    final body = StreamBuilder<List<SubscriptionPaymentModel>>(
      stream: repo.watchPendingPayments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: AdminTheme.mutedStyle(),
            ),
          );
        }

        final payments = snapshot.data ?? [];
        if (payments.isEmpty) {
          return Center(
            child: Text(
              'No pending subscription payments.',
              style: AdminTheme.mutedStyle(),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length,
          itemBuilder: (context, index) {
            return _PaymentReviewCard(payment: payments[index]);
          },
        );
      },
    );

    if (embedded) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Payment settings',
                icon: const Icon(Icons.settings_outlined, color: AdminColors.navy),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AdminTheme.wrap(
                      const AdminPaymentSettingsView(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AdminColors.screenBg,
      appBar: AdminAppBar(
        title: 'Subscription Payments',
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            tooltip: 'Payment settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AdminTheme.wrap(const AdminPaymentSettingsView()),
              ),
            ),
          ),
        ],
      ),
      body: body,
    );
  }
}

class _PaymentReviewCard extends StatefulWidget {
  final SubscriptionPaymentModel payment;

  const _PaymentReviewCard({required this.payment});

  @override
  State<_PaymentReviewCard> createState() => _PaymentReviewCardState();
}

class _PaymentReviewCardState extends State<_PaymentReviewCard> {
  bool _processing = false;

  PlanDefinition? _planFor(String planKey) {
    try {
      return kPlans.firstWhere((p) => p.planKey == planKey);
    } catch (_) {
      return null;
    }
  }

  void _viewProof() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminAppBar(
              title: 'Payment screenshot',
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  widget.payment.paymentProofUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load image',
                      style: AdminTheme.mutedStyle(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve() async {
    final plan = _planFor(widget.payment.plan);
    if (plan == null) return;

    setState(() => _processing = true);
    final adminUid = context.read<AuthViewModel>().user?.uid ?? '';
    await context.read<SubscriptionPaymentRepository>().approvePayment(
          payment: widget.payment,
          adminUid: adminUid,
          plan: plan,
        );
    if (mounted) setState(() => _processing = false);
  }

  Future<void> _reject() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject payment'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: AdminTheme.inputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'e.g. Payment screenshot unclear',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
            style: AdminTheme.primaryButtonStyle(height: 44),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !mounted) return;

    setState(() => _processing = true);
    final adminUid = context.read<AuthViewModel>().user?.uid ?? '';
    await context.read<SubscriptionPaymentRepository>().rejectPayment(
          payment: widget.payment,
          adminUid: adminUid,
          reason: reason.isEmpty ? 'Payment could not be verified.' : reason,
        );
    if (mounted) setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;

    return AdminCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AdminColors.navy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.workspace_premium,
                    color: AdminColors.navy, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.companyName,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AdminColors.navy,
                      ),
                    ),
                    Text(
                      '${payment.planLabel} plan',
                      style: AdminTheme.mutedStyle(size: 12),
                    ),
                  ],
                ),
              ),
              Text(
                'Rs ${payment.amount}',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AdminColors.navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('MMM dd, yyyy • hh:mm a').format(payment.submittedAt),
            style: AdminTheme.mutedStyle(size: 12),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: _viewProof,
              child: Image.network(
                payment.paymentProofUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: AdminColors.screenBg,
                  alignment: Alignment.center,
                  child: Text(
                    'Tap to view screenshot',
                    style: AdminTheme.mutedStyle(size: 12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _processing ? null : _reject,
                  style: AdminTheme.destructiveButtonStyle(),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _processing ? null : _approve,
                  style: AdminTheme.primaryButtonStyle(height: 46),
                  child: _processing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
