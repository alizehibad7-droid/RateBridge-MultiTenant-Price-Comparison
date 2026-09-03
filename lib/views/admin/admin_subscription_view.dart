import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../theme/admin_theme.dart';
import '../../utils/formatters.dart';
import '../../models/subscription_model.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import '../../widgets/admin/admin_widgets.dart';

class AdminSubscriptionView extends StatefulWidget {
  const AdminSubscriptionView({
    super.key,
    @visibleForTesting this.debugFirestore,
    @visibleForTesting this.debugLoadGate,
  });

  final FirebaseFirestore? debugFirestore;

  /// When set, [_loadCompanies] waits on this future after flipping the
  /// loading flag so widget tests can observe the spinner.
  final Future<void>? debugLoadGate;

  @override
  State<AdminSubscriptionView> createState() => _AdminSubscriptionViewState();
}

class _AdminSubscriptionViewState extends State<AdminSubscriptionView> {
  late final FirebaseFirestore _firestore;
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _filtered = [];
  Map<String, SubscriptionModel?> _subscriptions = {};
  bool _loadingCompanies = true;

  @override
  void initState() {
    super.initState();
    _firestore = widget.debugFirestore ?? FirebaseFirestore.instance;
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
      if (widget.debugLoadGate != null) {
        await widget.debugLoadGate;
      }
      final snap = await _firestore
          .collection('companies')
          .where('status', isEqualTo: 'active')
          .get();

      final companies = snap.docs
          .map((d) => {
                'id': d.id,
                ...d.data(),
                'companyName': d.data()['name'] ?? d.data()['companyName'] ?? 'Unknown'
              })
          .toList();

      companies.sort((a, b) =>
          (a['companyName'] as String).compareTo(b['companyName'] as String));

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
      backgroundColor: AdminColors.screenBg,
      appBar: AdminAppBar(
        title: 'Subscription Management',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadCompanies,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
              decoration: AdminTheme.inputDecoration(
                hintText: 'Search by company name...',
                prefixIcon: const Icon(Icons.search_rounded, color: AdminColors.navy, size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel_rounded, size: 20, color: AdminColors.textGrey),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                          setState(() {});
                        },
                      )
                    : null,
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
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: AdminTheme.cardDecoration(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summaryItem(Icons.eco_rounded, 'Free', freeCount, AdminColors.textGrey),
                  _summaryItem(Icons.star_outline_rounded, 'Basic', basicCount, AdminColors.navy),
                  _summaryItem(Icons.workspace_premium_rounded, 'Premium', premiumCount, AdminColors.amber),
                  _summaryItem(Icons.groups_rounded, 'Total', _companies.length, AdminColors.green),
                ],
              ),
            );
          }),
          Expanded(
            child: _loadingCompanies
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.business_rounded, size: 64, color: AdminColors.textGrey),
                            const SizedBox(height: 16),
                            Text(
                              'No companies found',
                              style: AdminTheme.titleStyle(size: 18).copyWith(color: AdminColors.textGrey),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCompanies,
                        color: AdminColors.amber,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final company = _filtered[i];
                            final companyId = company['id'] as String;
                            final sub = _subscriptions[companyId];
                            return _companySubscriptionCard(
                              context,
                              company,
                              sub,
                              companyId,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(IconData icon, String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AdminColors.navy,
          ),
        ),
        Text(label, style: AdminTheme.mutedStyle(size: 10).copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _companySubscriptionCard(
    BuildContext context,
    Map<String, dynamic> company,
    SubscriptionModel? sub,
    String companyId,
  ) {
    final name = company['companyName'] as String? ?? 'Company';
    final city = company['city'] as String? ?? '';
    final currentPlan = sub?.plan ?? 'free';
    final adminGranted = sub?.adminGranted ?? false;
    final expiresAt = sub?.expiresAt;

    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AdminColors.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'C',
                    style: GoogleFonts.plusJakartaSans(
                      color: AdminColors.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AdminColors.navy,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: AdminColors.textGrey),
                        const SizedBox(width: 4),
                        Text(city, style: AdminTheme.mutedStyle(size: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _planBadge(currentPlan),
                  if (adminGranted) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.admin_panel_settings_rounded, size: 12, color: AdminColors.navy),
                        const SizedBox(width: 4),
                        Text(
                          'Admin Grant',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: AdminColors.navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (expiresAt != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AdminColors.screenBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_available_rounded,
                      size: 14, color: AdminColors.textGrey),
                  const SizedBox(width: 8),
                  Text(
                    'Expires ${AppFormatters.date(expiresAt)}',
                    style: AdminTheme.mutedStyle(size: 12).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AdminColors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${sub?.daysRemaining ?? 0} days left',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: AdminColors.darkAmber,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 16, color: AdminColors.amber),
              const SizedBox(width: 6),
              Text(
                'Grant Plan:',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AdminColors.navy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: kPlans
                        .where((p) => p.id != PlanId.free)
                        .map((plan) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: OutlinedButton(
                                onPressed: currentPlan == plan.planKey
                                    ? null
                                    : () => _showGrantDialog(
                                          context,
                                          company,
                                          companyId,
                                          plan,
                                        ),
                                style: AdminTheme.secondaryButtonStyle(height: 36).copyWith(
                                  padding: const WidgetStatePropertyAll(
                                    EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                  ),
                                  minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
                                  shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                ),
                                child: Text(plan.name,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
              if (currentPlan != 'free')
                IconButton(
                  onPressed: () =>
                      _revokeSubscription(context, companyId, name),
                  icon: const Icon(Icons.remove_circle_outline_rounded, color: AdminColors.red, size: 20),
                  tooltip: 'Revoke Subscription',
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGrantDialog(
    BuildContext context,
    Map<String, dynamic> company,
    String companyId,
    PlanDefinition plan,
  ) {
    final noteController = TextEditingController();
    final companyName = company['companyName'] as String? ?? 'Company';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: AdminColors.navy),
            const SizedBox(width: 10),
            Expanded(child: Text('Grant ${plan.name}')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Company: $companyName',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AdminColors.navy),
            ),
            const SizedBox(height: 8),
            Text(
              'This will manually activate the ${plan.name} plan for ${plan.durationDays} days as an administrative override.',
              style: AdminTheme.mutedStyle(size: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: noteController,
              maxLines: 3,
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
              decoration: AdminTheme.inputDecoration(
                labelText: 'Reason for manual grant',
                hintText: 'e.g. Promotional offer, support resolution...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton.icon(
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
                  behavior: SnackBarBehavior.floating,
                  content: Text(vm.successMessage ?? '${plan.name} plan successfully granted.'),
                  backgroundColor: AdminColors.green,
                ));
                vm.clearMessages();
              }
              await _loadCompanies();
            },
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text('GRANT ${plan.name.toUpperCase()}'),
            style: AdminTheme.primaryButtonStyle(height: 44).copyWith(
              minimumSize: WidgetStateProperty.all(const Size(160, 44)),
            ),
          ),
        ],
      ),
    );
  }

  void _revokeSubscription(
      BuildContext context, String companyId, String companyName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AdminColors.red),
            const SizedBox(width: 10),
            const Text('Revoke Subscription?'),
          ],
        ),
        content: Text(
            'Are you sure you want to revoke paid access for $companyName? '
            'This will immediately revert the workspace to the Free plan limitations.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          OutlinedButton.icon(
            style: AdminTheme.destructiveButtonStyle(height: 44).copyWith(
              minimumSize: WidgetStateProperty.all(const Size(140, 44)),
            ),
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
                    'note': 'Revoked by administrator',
                  }
                ]),
              }, SetOptions(merge: true));

              await _firestore.collection('companies').doc(companyId).update({
                'plan': 'free',
                'planExpiry': null,
                'aiEnabled': false,
              });

              await _loadCompanies();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    behavior: SnackBarBehavior.floating,
                    content: Text('Subscription has been revoked.'),
                    backgroundColor: AdminColors.amber,
                  ),
                );
              }
            },
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
            label: const Text('CONFIRM REVOKE'),
          ),
        ],
      ),
    );
  }

  Widget _planBadge(String plan) {
    final colors = plan == 'premium'
            ? AdminTheme.statusColors('pending')
            : plan == 'basic'
                ? AdminTheme.statusColors('approved')
                : AdminTheme.statusColors('suspended');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        plan.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: colors.fg,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
