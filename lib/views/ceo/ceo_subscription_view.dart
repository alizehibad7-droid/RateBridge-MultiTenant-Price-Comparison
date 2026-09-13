import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/ceo_theme.dart';
import '../../constants/route_names.dart';
import '../../models/subscription_model.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import '../../widgets/ceo/ceo_widgets.dart';
import '../payment/payment_method_view.dart';
import '../../models/payment_proof_model.dart';

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
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: CeoColors.red),
            const SizedBox(width: 10),
            const Text('Cancel Subscription?'),
          ],
        ),
        content: const Text('Your plan will be downgraded to FREE immediately. You will lose access to premium features.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('KEEP IT')),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context.read<SubscriptionViewModel>().cancelSubscription(companyId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: CeoColors.red),
            icon: const Icon(Icons.cancel_rounded, size: 18, color: Colors.white),
            label: const Text('CANCEL PLAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: CeoAppBar(title: 'Plan & Billing', actions: [
        IconButton(
          icon: const Icon(Icons.account_circle_rounded), 
          tooltip: 'Profile',
          onPressed: () => context.push(RouteNames.ceoProfile)
        ),
      ]),
      body: Consumer<SubscriptionViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading && viewModel.currentSubscription == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final sub = viewModel.currentSubscription;
          final planDef = sub?.planDef ?? kPlans.first;
          final isPending = viewModel.isWaitingVerification;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (viewModel.error != null) 
                _Banner(
                  icon: Icons.error_outline_rounded,
                  text: viewModel.error!, 
                  color: CeoColors.red
                ),
              if (viewModel.successMessage != null) 
                _Banner(
                  icon: Icons.check_circle_outline_rounded,
                  text: viewModel.successMessage!, 
                  color: CeoColors.green
                ),
              
              if (isPending) 
                _buildPendingVerificationCard(viewModel.pendingPayment),
              
              _buildCurrentPlanCard(sub, planDef),
              const SizedBox(height: 24),
              _buildAiStatusCard(planDef.aiUnlocked && (sub?.isActive ?? false)),
              const SizedBox(height: 32),
              
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: CeoColors.amber, size: 22),
                  const SizedBox(width: 8),
                  const CeoSectionLabel('Available Plans'),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: kPlans.map((plan) => Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _buildPlanOption(plan, sub?.plan == plan.planKey, isPending, () {
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
              Row(
                children: [
                  const Icon(Icons.history_rounded, color: CeoColors.navy, size: 22),
                  const SizedBox(width: 8),
                  const CeoSectionLabel('Billing History'),
                ],
              ),
              const SizedBox(height: 12),
              if (viewModel.history.isEmpty) 
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: CeoTheme.cardDecoration(),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long_rounded, color: CeoColors.textGrey, size: 40),
                        const SizedBox(height: 12),
                        Text('No billing history found.', style: CeoTheme.mutedStyle()),
                      ],
                    ),
                  ),
                )
              else ...viewModel.history.map(_buildHistoryTile),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPendingVerificationCard(PaymentProofModel? payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CeoColors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CeoColors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: CeoColors.amber,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Payment Verification Pending', 
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: CeoColors.navy)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your payment for the ${payment?.planName ?? "selected"} plan is currently under review. Premium features will be unlocked immediately once confirmed by the admin.',
            style: CeoTheme.mutedStyle(size: 13).copyWith(color: CeoColors.darkAmber, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanCard(SubscriptionModel? sub, PlanDefinition planDef) {
    final textTheme = Theme.of(context).textTheme;
    final isFree = sub?.plan == 'free';
    final isActive = sub?.isActive ?? false;

    return AdminCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CeoSectionLabel('CURRENT PLAN'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isActive ? CeoColors.amber.withValues(alpha: 0.1) : CeoColors.textGrey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isFree ? Icons.eco_rounded : Icons.workspace_premium_rounded,
                      color: isActive ? CeoColors.amber : CeoColors.textGrey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(planDef.name.toUpperCase(), 
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: CeoColors.navy, fontSize: 20)),
                ],
              ),
              _StatusBadge(active: isActive),
            ],
          ),
          const SizedBox(height: 16),
          if (isActive && sub?.expiresAt != null)
            Row(
              children: [
                const Icon(Icons.event_available_rounded, size: 14, color: CeoColors.textGrey),
                const SizedBox(width: 6),
                Text('Renews on ${DateFormat('MMM dd, yyyy').format(sub!.expiresAt!)}', 
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: CeoColors.navy, fontWeight: FontWeight.w600)),
              ],
            )
          else if (isActive && sub?.expiresAt == null)
            Row(
              children: [
                const Icon(Icons.all_inclusive_rounded, size: 14, color: CeoColors.textGrey),
                const SizedBox(width: 6),
                Text('Lifetime Access', 
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: CeoColors.navy, fontWeight: FontWeight.w600)),
              ],
            )
          else if (!isActive && !isFree)
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 14, color: CeoColors.red),
                const SizedBox(width: 6),
                Text('Subscription Expired', 
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: CeoColors.red, fontWeight: FontWeight.w700)),
              ],
            )
          else
            Text('Enjoy basic construction material procurement features.', style: CeoTheme.mutedStyle()),
          
          if (!isFree && isActive) ...[
             const SizedBox(height: 20),
             const Divider(),
             const SizedBox(height: 12),
             SizedBox(
               width: double.infinity,
               child: TextButton.icon(
                 onPressed: () => _confirmCancellation(sub!.companyId),
                 icon: const Icon(Icons.cancel_outlined, size: 16, color: CeoColors.red),
                 label: const Text('CANCEL SUBSCRIPTION'),
                 style: TextButton.styleFrom(foregroundColor: CeoColors.red),
               ),
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
        color: isUnlocked ? CeoColors.green.withValues(alpha: 0.08) : CeoColors.textGrey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isUnlocked ? CeoColors.green.withValues(alpha: 0.2) : CeoColors.border),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isUnlocked ? CeoColors.green : CeoColors.textGrey,
            shape: BoxShape.circle,
          ),
          child: Icon(isUnlocked ? Icons.auto_awesome_rounded : Icons.lock_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUnlocked ? 'AI Market Insights Active' : 'AI Market Insights Locked',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isUnlocked ? CeoColors.green : CeoColors.navy,
                ),
              ),
              Text(
                isUnlocked ? 'Advanced analytics enabled' : 'Upgrade to unlock intelligent price predictions',
                style: CeoTheme.mutedStyle(size: 11),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildPlanOption(PlanDefinition plan, bool isCurrent, bool isPending, VoidCallback? onSelect) {
    return Container(
      width: 240, padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isCurrent ? CeoColors.amber : CeoColors.border, width: isCurrent ? 2.5 : 1),
        boxShadow: isCurrent ? [
          BoxShadow(color: CeoColors.amber.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))
        ] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(plan.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18, color: CeoColors.navy)),
              if (plan.id == PlanId.premium) 
                const Icon(Icons.workspace_premium_rounded, color: CeoColors.amber, size: 20),
            ],
          ),
          const SizedBox(height: 4),
          Text(plan.priceRs == 0 ? 'Free' : 'Rs. ${plan.priceRs}/mo', 
            style: GoogleFonts.plusJakartaSans(color: CeoColors.amber, fontWeight: FontWeight.w900, fontSize: 16)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),
          ...plan.features.map((f) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.check_circle_rounded, size: 16, color: CeoColors.green),
            const SizedBox(width: 10),
            Expanded(child: Text(f, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, color: CeoColors.navy))),
          ]))),
          const SizedBox(height: 16),
          if (isCurrent) 
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: CeoColors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text('CURRENT PLAN', 
                style: GoogleFonts.plusJakartaSans(color: CeoColors.darkAmber, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1))),
            )
          else if (plan.id != PlanId.free) 
            ElevatedButton.icon(
              onPressed: isPending ? null : onSelect, 
              icon: Icon(isPending ? Icons.hourglass_top_rounded : Icons.bolt_rounded),
              label: Text(isPending ? 'PENDING' : 'SELECT PLAN'),
              style: CeoTheme.primaryButtonStyle(height: 48),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(SubscriptionHistoryEntry entry) {
    final actionLabel = entry.action.replaceAll('_', ' ').toUpperCase();
    final isCharge = entry.amountPaid != null && entry.amountPaid! > 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: CeoTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CeoColors.navy.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCharge ? Icons.receipt_rounded : Icons.history_rounded,
              color: CeoColors.navy,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${entry.plan.toUpperCase()} PLAN', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: CeoColors.navy, fontSize: 14)),
            Text(actionLabel, style: CeoTheme.mutedStyle(size: 11).copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(DateFormat('MMM dd, yyyy').format(entry.date), style: CeoTheme.mutedStyle(size: 11)),
          ])),
          if (isCharge) 
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Rs. ${entry.amountPaid}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: CeoColors.navy)),
                Text('PAID', style: GoogleFonts.plusJakartaSans(color: CeoColors.green, fontWeight: FontWeight.w900, fontSize: 10)),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool active;
  const _StatusBadge({required this.active});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
      decoration: BoxDecoration(
        color: (active ? CeoColors.green : CeoColors.textGrey).withValues(alpha: 0.15), 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (active ? CeoColors.green : CeoColors.textGrey).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? Icons.check_circle_rounded : Icons.info_outline_rounded, size: 12, color: active ? CeoColors.green : CeoColors.textGrey),
          const SizedBox(width: 4),
          Text(active ? 'ACTIVE' : 'INACTIVE', 
            style: GoogleFonts.plusJakartaSans(color: active ? CeoColors.green : CeoColors.textGrey, fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text; final Color color; final IconData icon;
  const _Banner({required this.text, required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(14), 
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: GoogleFonts.plusJakartaSans(color: color, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
