import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../models/subscription_model.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import '../../widgets/app_text_field.dart';
import '../../constants/app_colors.dart';

class AdminSubscriptionView extends StatefulWidget {
  const AdminSubscriptionView({super.key});

  @override
  State<AdminSubscriptionView> createState() => _AdminSubscriptionViewState();
}

class _AdminSubscriptionViewState extends State<AdminSubscriptionView> {
  final _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _filtered = [];
  Map<String, SubscriptionModel?> _subscriptions = {};
  bool _loadingCompanies = true;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    setState(() => _loadingCompanies = true);
    try {
      final snap = await _firestore
          .collection('companies')
          .where('status', isEqualTo: 'active')
          .get();

      final companies = snap.docs
          .map((d) => {'id': d.id, ...d.data(), 'companyName': d.data()['name'] ?? d.data()['companyName'] ?? 'Unknown'})
          .toList();

      // Sort locally since field names might vary
      companies.sort((a, b) => (a['companyName'] as String).compareTo(b['companyName'] as String));

      final subFutures = companies.map((c) async {
        final subDoc = await _firestore
            .collection('subscriptions')
            .doc(c['id'] as String)
            .get();
        return MapEntry<String, SubscriptionModel?>(
          c['id'] as String,
          subDoc.exists
              ? SubscriptionModel.fromMap(
                  c['id'] as String,
                  subDoc.data() as Map<String, dynamic>)
              : null,
        );
      });

      final subEntries = await Future.wait(subFutures);
      setState(() {
        _companies = companies;
        _filtered = companies;
        _subscriptions = Map.fromEntries(subEntries);
        _loadingCompanies = false;
      });
    } catch (e) {
      setState(() => _loadingCompanies = false);
    }
  }

  void _onSearch(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _filtered = query.isEmpty
            ? _companies
            : _companies
                .where((c) => (c['companyName'] as String? ?? '')
                    .toLowerCase()
                    .contains(query.toLowerCase()))
                .toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Subscription Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCompanies,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              decoration: const InputDecoration(
                hintText: 'Search company...',
                prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
              ),
            ),
          ),
          Consumer<SubscriptionViewModel>(builder: (_, __, ___) {
            final basicCount = _subscriptions.values
                .where((s) => s?.plan == 'basic' && s!.isActive)
                .length;
            final premiumCount = _subscriptions.values
                .where((s) => s?.plan == 'premium' && s!.isActive)
                .length;
            final freeCount = _companies.length - basicCount - premiumCount;

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(12),
              decoration: appCardDecoration(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summaryPill('Free', freeCount, AppColors.textSecondary),
                  _summaryPill('Basic', basicCount, AppColors.primary),
                  _summaryPill('Premium', premiumCount, AppColors.warning),
                  _summaryPill('Total', _companies.length, AppColors.adminAccent),
                ],
              ),
            );
          }),
          Expanded(
            child: _loadingCompanies
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(
                        child: Text('No companies found',
                            style: AppTextStyles.bodyMuted))
                    : RefreshIndicator(
                        onRefresh: _loadCompanies,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final company = _filtered[i];
                            final companyId = company['id'] as String;
                            final sub = _subscriptions[companyId];
                            return _companySubscriptionCard(context, company, sub, companyId);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _companySubscriptionCard(BuildContext context, Map<String, dynamic> company, SubscriptionModel? sub, String companyId) {
    final name = company['companyName'] as String? ?? 'Company';
    final city = company['city'] as String? ?? '';
    final currentPlan = sub?.plan ?? 'free';
    final adminGranted = sub?.adminGranted ?? false;
    final expiresAt = sub?.expiresAt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.infoBg,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'C',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(city, style: AppTextStyles.bodyMuted),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _planBadge(currentPlan),
                  if (adminGranted) ...[
                    const SizedBox(height: 3),
                    const Text('Admin Grant',
                        style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ],
          ),
          if (expiresAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Expires: ${AppFormatters.date(expiresAt)}  ·  ${sub?.daysRemaining ?? 0} days left',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Grant:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 10),
              ...kPlans
                  .where((p) => p.id != PlanId.free)
                  .map((plan) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OutlinedButton(
                          onPressed: currentPlan == plan.planKey
                              ? null
                              : () => _showGrantDialog(context, company, companyId, plan),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: plan.id == PlanId.premium ? AppColors.warning : AppColors.primary,
                            side: BorderSide(color: plan.id == PlanId.premium ? AppColors.warning : AppColors.primary),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(plan.name, style: const TextStyle(fontSize: 12)),
                        ),
                      )),
              const Spacer(),
              if (currentPlan != 'free')
                TextButton(
                  onPressed: () => _revokeSubscription(context, companyId, name),
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  child: const Text('Revoke', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGrantDialog(BuildContext context, Map<String, dynamic> company, String companyId, PlanDefinition plan) {
    final noteController = TextEditingController();
    final companyName = company['companyName'] as String? ?? 'Company';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Grant ${plan.name} to $companyName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will activate ${plan.name} for ${plan.durationDays} days at no charge (admin override).',
              style: AppTextStyles.bodyMuted,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'ADMIN NOTE (optional)',
              controller: noteController,
              maxLines: 2,
              hint: 'Reason for granting...',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final vm = context.read<SubscriptionViewModel>();
              await vm.adminGrantPlan(
                companyId: companyId,
                plan: plan,
                note: noteController.text,
              );
              if (ctx.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(vm.successMessage ?? '${plan.name} granted.'),
                  backgroundColor: AppColors.success,
                ));
                vm.clearMessages();
              }
              await _loadCompanies();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: plan.id == PlanId.premium ? AppColors.warning : AppColors.primary,
            ),
            child: Text('Grant ${plan.name}', style: AppTextStyles.button),
          ),
        ],
      ),
    );
  }

  void _revokeSubscription(BuildContext context, String companyId, String companyName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Revoke subscription for $companyName?'),
        content: const Text('This will immediately revert the company to the Free plan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              await _firestore.collection('subscriptions').doc(companyId).set({
                'plan': 'free',
                'status': 'active',
                'startedAt': FieldValue.serverTimestamp(),
                'expiresAt': null,
                'adminGranted': false,
                'history': FieldValue.arrayUnion([
                  {
                    'plan': 'free',
                    'action': 'admin_revoked',
                    'date': Timestamp.now(),
                    'amountPaid': 0,
                    'note': 'Revoked by admin',
                  }
                ]),
              }, SetOptions(merge: true));
              await _loadCompanies();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Subscription revoked.'), backgroundColor: AppColors.warning),
                );
              }
            },
            child: const Text('Revoke', style: AppTextStyles.button),
          ),
        ],
      ),
    );
  }

  Widget _planBadge(String plan) {
    Color color = plan == 'premium' ? AppColors.warning : (plan == 'basic' ? AppColors.primary : AppColors.textSecondary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        plan.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _summaryPill(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}
