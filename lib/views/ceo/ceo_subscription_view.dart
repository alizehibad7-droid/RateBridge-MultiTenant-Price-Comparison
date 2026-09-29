import 'package:flutter/foundation.dart';
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
import '../../services/stripe_service.dart';
import '../../utils/app_exception.dart';

class CeoSubscriptionView extends StatefulWidget {
  const CeoSubscriptionView({super.key});

  @override
  State<CeoSubscriptionView> createState() => _CeoSubscriptionViewState();
}

class _CeoSubscriptionViewState extends State<CeoSubscriptionView> {
  bool _handlingPaymentReturn = false;
  bool _activationDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    if (_handlingPaymentReturn || _activationDone) return;

    final auth = context.read<AuthViewModel>();
    final subVm = context.read<SubscriptionViewModel>();
    subVm.setBusyMessage('Loading your plan…');

    var companyId = auth.user?.companyId ?? '';
    if (companyId.isEmpty) {
      for (var i = 0; i < 20 && companyId.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (!mounted) return;
        companyId = context.read<AuthViewModel>().user?.companyId ?? '';
      }
    }
    if (companyId.isEmpty) {
      subVm.setBusyMessage(null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not load your company. Sign out and sign in, then open Plan & Billing again.',
            ),
          ),
        );
      }
      return;
    }

    final stripe = context.read<StripeService>();
    final stripeStatus = _queryFromUrl('stripe');
    final urlPlan = _queryFromUrl('plan');
    final pending = await stripe.readPendingSubscription();

    final shouldActivate = stripeStatus == 'success' || pending != null;
    if (shouldActivate) {
      _handlingPaymentReturn = true;
      final planKey = (urlPlan != null && urlPlan.isNotEmpty)
          ? urlPlan
          : (pending?.plan ?? '');
      final activateCompanyId =
          (pending?.companyId.isNotEmpty == true) ? pending!.companyId : companyId;
      final amount = pending?.amountPKR;

      final plan = kPlans.firstWhere(
        (p) => p.planKey == planKey,
        orElse: () => kPlans.first,
      );

      if (plan.id == PlanId.free) {
        await subVm.loadSubscription(companyId, fromServer: true);
        subVm.setBusyMessage(null);
        _handlingPaymentReturn = false;
        return;
      }

      await _activatePaidPlan(
        companyId: activateCompanyId,
        plan: plan,
        amountPKR: amount ?? plan.priceRs,
      );
      _handlingPaymentReturn = false;
      return;
    }

    await subVm.loadSubscription(companyId, fromServer: true);
    subVm.setBusyMessage(null);
    if (stripeStatus == 'cancel' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment cancelled.')),
      );
    }
  }

  Future<void> _activatePaidPlan({
    required String companyId,
    required PlanDefinition plan,
    required int amountPKR,
  }) async {
    final subVm = context.read<SubscriptionViewModel>();
    final stripe = context.read<StripeService>();

    // 1) Instant UI — never wait for restart / Cloud Function.
    subVm.applyLocalPlan(
      companyId: companyId,
      plan: plan,
      amountPaid: amountPKR,
    );
    _activationDone = true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${plan.name} plan is now active.')),
      );
    }

    // 2) Persist quickly via client write (source of truth for this screen).
    subVm.setBusyMessage('Saving your plan…');
    try {
      await subVm.activateSubscription(
        companyId: companyId,
        plan: plan,
        adminGranted: false,
        amountPaid: amountPKR,
      );
      await stripe.clearPendingSubscription();
      subVm.setBusyMessage(null);
    } catch (e, st) {
      debugPrint('Client activate failed, trying admin job: $e\n$st');
      // 3) Fallback: Admin SDK job (slower, but reliable).
      subVm.setBusyMessage('Finalizing payment…');
      try {
        await stripe.claimSubscriptionActivation(
          companyId: companyId,
          plan: plan.planKey,
          amountPKR: amountPKR,
        );
        await subVm.loadSubscription(companyId, fromServer: true);
        subVm.setBusyMessage(null);
      } catch (e2) {
        subVm.setBusyMessage(null);
        debugPrint('Admin activate also failed: $e2');
        // Keep local plan on screen; data may still sync via Stripe webhook.
      }
    }
  }

  Future<void> _selectPlan(PlanDefinition plan) async {
    if (plan.id == PlanId.free) return;
    final subVm = context.read<SubscriptionViewModel>();
    final authVm = context.read<AuthViewModel>();
    final companyId = authVm.user?.companyId ?? '';
    if (companyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company not loaded. Sign in again and retry.'),
        ),
      );
      return;
    }

    subVm.setBusyMessage('Opening secure checkout…');
    try {
      final stripe = context.read<StripeService>();
      final outcome = await stripe.payWithStripe(
        type: 'subscription',
        plan: plan.planKey,
        companyId: companyId,
        amountPKR: plan.priceRs,
      );
      if (outcome == StripePayOutcome.redirected) {
        // Browser navigates to Stripe — keep message until unload.
        subVm.setBusyMessage('Redirecting to Stripe…');
        return;
      }
      subVm.setBusyMessage('Activating ${plan.name} plan…');
      subVm.applyLocalPlan(
        companyId: companyId,
        plan: plan,
        amountPaid: plan.priceRs,
      );
      await subVm.activateSubscription(
        companyId: companyId,
        plan: plan,
        adminGranted: false,
        amountPaid: plan.priceRs,
      );
      subVm.setBusyMessage(null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${plan.name} plan is now active.')),
      );
    } catch (e) {
      subVm.setBusyMessage(null);
      if (!mounted) return;
      if (e is AppException && e.code == 'canceled') return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is AppException ? e.message : e.toString()),
        ),
      );
    }
  }

  /// Supports ?stripe= on the URI and hash routes (#/path?stripe=&plan=).
  String? _queryFromUrl(String key) {
    final direct = Uri.base.queryParameters[key];
    if (direct != null && direct.isNotEmpty) return direct;

    final fragment = Uri.base.fragment;
    final q = fragment.indexOf('?');
    if (q < 0) return null;
    return Uri.splitQueryString(fragment.substring(q + 1))[key];
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
      appBar: const CeoAppBar(
        title: 'Plan & Billing',
        showNotificationIcon: false,
        backFallbackRoute: RouteNames.ceoProfile,
      ),
      body: Consumer<SubscriptionViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading && viewModel.currentSubscription == null && !viewModel.isBusy) {
            return const Center(child: CircularProgressIndicator());
          }

          final sub = viewModel.currentSubscription;
          final planDef = sub?.planDef ?? kPlans.first;
          return Stack(
            children: [
              ListView(
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
              
              _buildCurrentPlanCard(sub, planDef),
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
                    child: _buildPlanOption(
                      plan,
                      sub?.plan == plan.planKey,
                      viewModel.isBusy,
                      viewModel.isBusy ? null : () => _selectPlan(plan),
                    ),
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
              ),
              if (viewModel.isBusy)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              viewModel.busyMessage ?? 'Please wait…',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: CeoColors.navy,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This can take up to ~20 seconds. Do not close the page.',
                              textAlign: TextAlign.center,
                              style: CeoTheme.mutedStyle(size: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurrentPlanCard(SubscriptionModel? sub, PlanDefinition planDef) {
    final isFree = sub == null || planDef.id == PlanId.free || sub.plan == 'free';
    // Free is always "active" in the UI; never show as expired.
    final isActive = isFree ? true : (sub?.isActive ?? false);

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
          if (isFree)
            Text(
              'Free plan — always available. Upgrade anytime for more capacity.',
              style: CeoTheme.mutedStyle(),
            )
          else if (isActive && sub?.expiresAt != null)
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
          else
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 14, color: CeoColors.red),
                const SizedBox(width: 6),
                Text('Subscription Expired — select a plan to renew', 
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: CeoColors.red, fontWeight: FontWeight.w700)),
              ],
            ),
          
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
