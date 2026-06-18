import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/subscription_model.dart';
import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';

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
      final authVM = context.read<AuthViewModel>();
      final companyId = authVM.user?.companyId ?? '';
      if (companyId.isNotEmpty) {
        context.read<SubscriptionViewModel>().loadSubscription(companyId);
      }
    });
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
          if (viewModel.isLoading) return const Center(child: CircularProgressIndicator());

          final sub = viewModel.currentSubscription;
          final planDef = sub?.planDef ?? kPlans.first;
          final daysRemaining = sub?.daysRemaining ?? 0;
          
          // Progress calculation: assume 30 days for visual representation if plan has duration
          final totalDays = planDef.durationDays > 0 ? planDef.durationDays : 30;
          final progress = (daysRemaining / totalDays).clamp(0.0, 1.0);

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (viewModel.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(viewModel.error!, style: const TextStyle(color: Colors.red)),
                ),
              if (viewModel.successMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(viewModel.successMessage!, style: const TextStyle(color: Colors.green)),
                ),

              // Current Plan Card
              _buildCurrentPlanCard(sub, planDef, daysRemaining, progress),
              const SizedBox(height: 32),

              // AI Status
              _buildAiStatusCard(planDef.aiUnlocked),
              const SizedBox(height: 32),

              const Text('Available Plans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Plan Cards
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
                        () {
                          final companyId = context.read<AuthViewModel>().user?.companyId ?? '';
                          viewModel.purchasePlan(companyId, plan);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () {
                  // Logic for billing portal could go here
                },
                child: const Text('MANAGE BILLING & PORTAL'),
              ),

              const SizedBox(height: 40),
              const Text('Billing History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (viewModel.history.isEmpty)
                const Text('No billing history found.', style: TextStyle(color: Colors.grey))
              else
                ...viewModel.history.map((h) => _buildHistoryTile(h)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurrentPlanCard(SubscriptionModel? sub, PlanDefinition planDef, int days, double progress) {
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
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.primary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (sub?.isActive ?? false) ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (sub?.isActive ?? false) ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(
                      color: (sub?.isActive ?? false) ? Colors.green : Colors.red,
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
                  : 'Expires: Never',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Usage Period', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('$days days remaining', style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: Colors.grey.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiStatusCard(bool isUnlocked) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.green.withOpacity(0.05) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isUnlocked ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(isUnlocked ? Icons.check_circle : Icons.lock, color: isUnlocked ? Colors.green : Colors.grey),
          const SizedBox(width: 12),
          Text(
            isUnlocked ? 'AI Market Insights Unlocked' : 'AI Market Insights Locked',
            style: TextStyle(fontWeight: FontWeight.bold, color: isUnlocked ? Colors.green : Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanOption(PlanDefinition plan, bool isCurrent, VoidCallback onUpgrade) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCurrent ? AppColors.primary : AppColors.border, width: 2),
        boxShadow: [
          if (isCurrent)
            BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            plan.priceRs == 0 ? 'Free' : 'Rs. ${plan.priceRs}/mo',
            style: const TextStyle(fontSize: 16, color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24),
          ...plan.features.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check, size: 14, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(child: Text(f, style: const TextStyle(fontSize: 12))),
              ],
            ),
          )),
          const Spacer(),
          const SizedBox(height: 16),
          if (!isCurrent)
            ElevatedButton(
              onPressed: onUpgrade,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('UPGRADE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            )
          else
            const Center(
              child: Text(
                'CURRENT PLAN',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
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
        title: Text('${entry.plan.toUpperCase()} Plan - ${entry.action.toUpperCase()}'),
        subtitle: Text(DateFormat('MMM dd, yyyy').format(entry.date)),
        trailing: entry.amountPaid != null && entry.amountPaid! > 0
            ? Text('Rs. ${entry.amountPaid}', style: const TextStyle(fontWeight: FontWeight.bold))
            : null,
      ),
    );
  }
}
