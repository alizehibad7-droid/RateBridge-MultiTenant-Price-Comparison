import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme/ceo_theme.dart';
import '../../constants/route_names.dart';
import '../../models/subscription_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import '../../widgets/ceo/ceo_widgets.dart';
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
      backgroundColor: CeoColors.screenBg,
      appBar: CeoAppBar(
        title: 'Subscription',
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
          final totalDays =
              planDef.durationDays > 0 ? planDef.durationDays : 30;
          final progress = (daysRemaining / totalDays).clamp(0.0, 1.0);
          final showExpiryWarning = sub?.isActive == true &&
              daysRemaining > 0 &&
              daysRemaining <= 7;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (viewModel.error != null)
                _Banner(text: viewModel.error!, color: CeoColors.red),
              if (viewModel.successMessage != null)
                _Banner(
                    text: viewModel.successMessage!, color: CeoColors.green),
              if (viewModel.hasPendingPayment)
                const _Banner(
                  text: 'Payment submitted — awaiting admin approval.',
                  color: CeoColors.amber,
                ),
              if (viewModel.hasRejectedPayment)
                _Banner(
                  text: viewModel.latestPayment?.rejectionReason?.isNotEmpty ==
                          true
                      ? 'Payment rejected: ${viewModel.latestPayment!.rejectionReason}'
                      : 'Your last payment was rejected. You can submit again.',
                  color: CeoColors.red,
                ),
              if (showExpiryWarning)
                _Banner(
                  text:
                      'Your subscription expires in $daysRemaining day${daysRemaining == 1 ? '' : 's'}. Renew to keep access.',
                  color: CeoColors.amber,
                ),
              _buildCurrentPlanCard(sub, planDef, daysRemaining, progress),
              const SizedBox(height: 24),
              _buildAiStatusCard(planDef.aiUnlocked),
              const SizedBox(height: 28),
              const CeoSectionLabel('Available Plans'),
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
              const CeoSectionLabel('Billing History'),
              const SizedBox(height: 12),
              if (viewModel.history.isEmpty)
                Text('No billing history found.',
                    style: CeoTheme.mutedStyle())
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

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                planDef.name.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: CeoColors.navy,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isActive ? CeoColors.green : CeoColors.textGrey)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'ACTIVE' : 'INACTIVE',
                  style: GoogleFonts.plusJakartaSans(
                    color: isActive ? CeoColors.green : CeoColors.textGrey,
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
            style: CeoTheme.mutedStyle(),
          ),
          if (planDef.durationDays > 0) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Days remaining',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CeoColors.navy,
                    )),
                Text('$days days', style: CeoTheme.mutedStyle(size: 12)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: CeoColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(CeoColors.amber),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAiStatusCard(bool isUnlocked) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked
            ? CeoColors.green.withValues(alpha: 0.05)
            : CeoColors.textGrey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked
              ? CeoColors.green.withValues(alpha: 0.2)
              : CeoColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(isUnlocked ? Icons.check_circle : Icons.lock,
              color: isUnlocked ? CeoColors.green : CeoColors.textGrey),
          const SizedBox(width: 12),
          Text(
            isUnlocked
                ? 'AI Market Insights Unlocked'
                : 'AI Market Insights Locked',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              color: isUnlocked ? CeoColors.green : CeoColors.textGrey,
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
      decoration: CeoTheme.cardDecoration(
        borderColor: isCurrent ? CeoColors.amber : CeoColors.border,
      ).copyWith(
        border: Border.all(
          color: isCurrent ? CeoColors.amber : CeoColors.border,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan.name, style: CeoTheme.titleStyle(size: 18)),
          const SizedBox(height: 4),
          Text(
            plan.priceRs == 0 ? 'Free' : 'Rs. ${plan.priceRs}/mo',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              color: CeoColors.navy,
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
                  const Icon(Icons.check, size: 14, color: CeoColors.green),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(f, style: CeoTheme.mutedStyle(size: 12))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (isCurrent)
            Center(
              child: Text(
                'CURRENT PLAN',
                style: GoogleFonts.plusJakartaSans(
                  color: CeoColors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            )
          else if (onSelect != null)
            ElevatedButton(
              onPressed: onSelect,
              style: CeoTheme.primaryButtonStyle(height: 40),
              child: Text(
                plan.id == PlanId.free ? 'FREE' : 'SELECT PLAN',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(SubscriptionHistoryEntry entry) {
    return AdminCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.plan.toUpperCase()} — ${entry.action.replaceAll('_', ' ')}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    color: CeoColors.navy,
                  ),
                ),
                Text(
                  DateFormat('MMM dd, yyyy').format(entry.date),
                  style: CeoTheme.mutedStyle(size: 12),
                ),
              ],
            ),
          ),
          if (entry.amountPaid != null && entry.amountPaid! > 0)
            Text(
              'Rs. ${entry.amountPaid}',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: CeoColors.navy,
              ),
            ),
        ],
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
      child: Text(
        text,
        style: GoogleFonts.plusJakartaSans(color: color, fontSize: 13),
      ),
    );
  }
}
