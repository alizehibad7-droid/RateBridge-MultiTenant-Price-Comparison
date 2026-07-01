import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';
import '../../models/subscription_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import 'ceo_subscription_payment_sheet.dart';

class CeoSubscriptionView extends StatefulWidget {
  const CeoSubscriptionView({super.key});

  @override
  State<CeoSubscriptionView> createState() => _CeoSubscriptionViewState();
}

class _CeoSubscriptionViewState extends State<CeoSubscriptionView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _bootstrap() {
    final auth = context.read<AuthViewModel>();
    final companyId = auth.user?.companyId ?? '';
    if (companyId.isEmpty) return;
    final vm = context.read<SubscriptionViewModel>();
    vm.loadSubscription(companyId);
    vm.watchLatestPayment(companyId);
  }

  void _onSelectPlan(PlanDefinition plan, SubscriptionModel? sub) {
    if (sub?.plan == plan.planKey) return;
    if (plan.id == PlanId.free) return;

    final vm = context.read<SubscriptionViewModel>();
    if (vm.hasPendingPayment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already have a payment pending review.'),
        ),
      );
      return;
    }

    CeoSubscriptionPaymentSheet.show(context, plan);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Subscription', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push(RouteNames.ceoProfile),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<SubscriptionViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading && viewModel.currentSubscription == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final sub = viewModel.currentSubscription;
          final planDef = sub?.planDef ?? kPlans.first;
          final daysRemaining = sub?.daysRemaining ?? 0;
          final totalDays = planDef.durationDays > 0 ? planDef.durationDays : 30;
          final progress = (daysRemaining / totalDays).clamp(0.0, 1.0);
          final showExpiryWarning =
              sub?.isActive == true && daysRemaining > 0 && daysRemaining <= 7;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (viewModel.error != null)
                _Banner(text: viewModel.error!, color: AppColors.error),
              if (viewModel.successMessage != null)
                _Banner(text: viewModel.successMessage!, color: AppColors.success),
              if (viewModel.hasPendingPayment)
                const _Banner(
                  text: 'Payment submitted — awaiting admin approval.',
                  color: AppColors.warning,
                ),
              if (viewModel.hasRejectedPayment)
                _Banner(
                  text: viewModel.latestPayment?.rejectionReason?.isNotEmpty == true
                      ? 'Payment rejected: ${viewModel.latestPayment!.rejectionReason}'
                      : 'Your last payment was rejected. You can submit again.',
                  color: AppColors.error,
                ),
              if (showExpiryWarning)
                _Banner(
                  text:
                      'Your subscription expires in $daysRemaining day${daysRemaining == 1 ? '' : 's'}. Renew to keep access.',
                  color: AppColors.warning,
                ),
              _buildCurrentPlanCard(sub, planDef, daysRemaining, progress),
              const SizedBox(height: 24),
              _buildAiStatusCard(planDef.aiUnlocked),
              const SizedBox(height: 28),
              const Text('Available Plans',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: kPlans.map((plan) {
                    final isCurrent = sub?.plan == plan.planKey;
                    return Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: _buildPlanOption(
                        plan,
                        isCurrent,
                        plan.id == PlanId.free
                            ? null
                            : () => _onSelectPlan(plan, sub),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 36),
              const Text('Billing History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (viewModel.history.isEmpty)
                const Text('No billing history found.',
                    style: TextStyle(color: Colors.grey))
              else
                ...viewModel.history.map(_buildHistoryTile),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurrentPlanCard(
    SubscriptionModel? sub,
    PlanDefinition planDef,
    int days,
    double progress,
  ) {
    final isActive = sub?.isActive ?? false;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  planDef.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(
                      color: isActive ? Colors.green : Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              sub?.expiresAt != null
                  ? 'Expires: ${DateFormat('MMM dd, yyyy').format(sub!.expiresAt!)}'
                  : 'No expiry date',
              style: const TextStyle(color: Colors.grey),
            ),
            if (planDef.durationDays > 0) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Days remaining',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('$days days',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiStatusCard(bool isUnlocked) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked
            ? Colors.green.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(isUnlocked ? Icons.check_circle : Icons.lock,
              color: isUnlocked ? Colors.green : Colors.grey),
          const SizedBox(width: 12),
          Text(
            isUnlocked
                ? 'AI Market Insights Unlocked'
                : 'AI Market Insights Locked',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isUnlocked ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanOption(
    PlanDefinition plan,
    bool isCurrent,
    VoidCallback? onSelect,
  ) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? AppColors.primary : AppColors.border,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan.name,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            plan.priceRs == 0 ? 'Free' : 'Rs. ${plan.priceRs}/mo',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 24),
          ...plan.features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check, size: 14, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f, style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (isCurrent)
            const Center(
              child: Text('CURRENT PLAN',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            )
          else if (onSelect != null)
            ElevatedButton(
              onPressed: onSelect,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(
                plan.id == PlanId.free ? 'FREE' : 'SELECT PLAN',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(SubscriptionHistoryEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
            '${entry.plan.toUpperCase()} — ${entry.action.replaceAll('_', ' ')}'),
        subtitle: Text(DateFormat('MMM dd, yyyy').format(entry.date)),
        trailing: entry.amountPaid != null && entry.amountPaid! > 0
            ? Text('Rs. ${entry.amountPaid}',
                style: const TextStyle(fontWeight: FontWeight.bold))
            : null,
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;

  const _Banner({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 13)),
    );
  }
}
