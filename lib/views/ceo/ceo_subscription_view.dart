import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme/ceo_theme.dart';
import '../../constants/route_names.dart';
import '../../models/subscription_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import '../../widgets/ceo/ceo_widgets.dart';
import '../payment/payment_method_view.dart';
import '../../models/payment_proof_model.dart'; // For PaymentType enum

class CeoSubscriptionView extends StatefulWidget {
  const CeoSubscriptionView({super.key});

  @override
  State<CeoSubscriptionView> createState() => _CeoSubscriptionViewState();
}

class _CeoSubscriptionViewState extends State<CeoSubscriptionView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  void _bootstrap() {
    final auth = context.read<AuthViewModel>();
    final companyId = auth.user?.companyId ?? '';
    if (companyId.isEmpty) return;
    context.read<SubscriptionViewModel>().loadSubscription(companyId);
  }

  void _confirmCancellation(String companyId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Subscription?'),
        content: const Text('Your plan will be downgraded to FREE immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('KEEP IT')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<SubscriptionViewModel>().cancelSubscription(companyId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: CeoColors.red),
            child: const Text('CANCEL PLAN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: CeoAppBar(title: 'Subscription', actions: [
        IconButton(icon: const Icon(Icons.account_circle_outlined), onPressed: () => context.push(RouteNames.ceoProfile)),
      ]),
      body: Consumer<SubscriptionViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading && viewModel.currentSubscription == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final sub = viewModel.currentSubscription;
          final planDef = sub?.planDef ?? kPlans.first;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (viewModel.error != null) _Banner(text: viewModel.error!, color: CeoColors.red),
              if (viewModel.successMessage != null) _Banner(text: viewModel.successMessage!, color: CeoColors.green),
              
              _buildCurrentPlanCard(sub, planDef),
              const SizedBox(height: 24),
              _buildAiStatusCard(planDef.aiUnlocked),
              const SizedBox(height: 28),
              const CeoSectionLabel('Available Plans'),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: kPlans.map((plan) => Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _buildPlanOption(plan, sub?.plan == plan.planKey, () {
                      if (plan.id != PlanId.free) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentMethodView(
                              amount: plan.priceRs.toDouble(),
                              type: PaymentType.subscription,
                              planKey: plan.planKey,
                            ),
                          ),
                        ).then((_) => _bootstrap());
                      }
                    }),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 36),
              const CeoSectionLabel('Billing History'),
              const SizedBox(height: 12),
              if (viewModel.history.isEmpty) Text('No billing history.', style: CeoTheme.mutedStyle())
              else ...viewModel.history.map(_buildHistoryTile),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurrentPlanCard(SubscriptionModel? sub, PlanDefinition planDef) {
    final textTheme = Theme.of(context).textTheme;
    final isFree = sub?.plan == 'free';
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(planDef.name.toUpperCase(), style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: CeoColors.navy)),
              _StatusBadge(active: sub?.isActive ?? false),
            ],
          ),
          const SizedBox(height: 8),
          Text(sub?.expiresAt != null ? 'Expires: ${DateFormat('MMM dd, yyyy').format(sub!.expiresAt!)}' : 'Lifetime Access', style: textTheme.bodyMedium),
          if (!isFree) ...[
             const SizedBox(height: 16),
             SizedBox(
               width: double.infinity,
               child: OutlinedButton.icon(
                 onPressed: () => _confirmCancellation(sub!.companyId),
                 icon: const Icon(Icons.cancel_outlined, size: 16),
                 label: const Text('CANCEL PLAN'),
                 style: OutlinedButton.styleFrom(foregroundColor: CeoColors.red, side: const BorderSide(color: CeoColors.red)),
               ),
             ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiStatusCard(bool isUnlocked) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked ? CeoColors.green.withValues(alpha: 0.05) : CeoColors.textGrey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isUnlocked ? CeoColors.green.withValues(alpha: 0.2) : CeoColors.border),
      ),
      child: Row(children: [
        Icon(isUnlocked ? Icons.check_circle : Icons.lock, color: isUnlocked ? CeoColors.green : CeoColors.textGrey),
        const SizedBox(width: 12),
        Text(
          isUnlocked ? 'AI Market Insights Unlocked' : 'AI Market Insights Locked',
          style: textTheme.titleSmall?.copyWith(color: isUnlocked ? CeoColors.green : CeoColors.textGrey),
        ),
      ]),
    );
  }

  Widget _buildPlanOption(PlanDefinition plan, bool isCurrent, VoidCallback? onSelect) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: 220, padding: const EdgeInsets.all(20),
      decoration: CeoTheme.cardDecoration(borderColor: isCurrent ? CeoColors.amber : CeoColors.border).copyWith(border: Border.all(color: isCurrent ? CeoColors.amber : CeoColors.border, width: isCurrent ? 2 : 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan.name, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          Text(plan.priceRs == 0 ? 'Free' : 'Rs. ${plan.priceRs}/mo', style: textTheme.titleMedium?.copyWith(color: CeoColors.navy, fontWeight: FontWeight.bold)),
          const Divider(height: 24),
          ...plan.features.map((f) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.check, size: 14, color: CeoColors.green),
            const SizedBox(width: 8),
            Expanded(child: Text(f, style: textTheme.bodySmall)),
          ]))),
          const SizedBox(height: 16),
          if (isCurrent) Center(child: Text('CURRENT', style: textTheme.labelLarge?.copyWith(color: CeoColors.amber, fontWeight: FontWeight.bold)))
          else if (plan.id != PlanId.free) ElevatedButton(onPressed: onSelect, child: const Text('SELECT PLAN')),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(SubscriptionHistoryEntry entry) {
    final textTheme = Theme.of(context).textTheme;
    return AdminCard(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${entry.plan.toUpperCase()} — ${entry.action.replaceAll('_', ' ')}', style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        Text(DateFormat('MMM dd, yyyy').format(entry.date), style: textTheme.bodySmall),
      ])),
      if (entry.amountPaid != null && entry.amountPaid! > 0) Text('Rs. ${entry.amountPaid}', style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
    ]));
  }
}

class _StatusBadge extends StatelessWidget {
  final bool active;
  const _StatusBadge({required this.active});
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: (active ? CeoColors.green : CeoColors.textGrey).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(active ? 'ACTIVE' : 'INACTIVE', style: textTheme.labelSmall?.copyWith(color: active ? CeoColors.green : CeoColors.textGrey, fontWeight: FontWeight.bold)));
  }
}

class _Banner extends StatelessWidget {
  final String text; final Color color;
  const _Banner({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(width: double.infinity, margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(text, style: textTheme.bodySmall?.copyWith(color: color)));
  }
}
