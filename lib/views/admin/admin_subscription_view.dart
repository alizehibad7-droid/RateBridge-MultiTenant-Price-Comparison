import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

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
      if (widget.debugLoadGate != null) await widget.debugLoadGate;
      final snap = await _firestore.collection('companies').where('status', isEqualTo: 'active').get();

      final companies = snap.docs.map((d) => {
        'id': d.id,
        ...d.data(),
        'companyName': d.data()['name'] ?? d.data()['companyName'] ?? 'Unknown Entity'
      }).toList();

      companies.sort((a, b) => (a['companyName'] as String).compareTo(b['companyName'] as String));

      final subFutures = companies.map((c) async {
        final subDoc = await _firestore.collection('subscriptions').doc(c['id'] as String).get();
        return MapEntry<String, SubscriptionModel?>(
          c['id'] as String,
          subDoc.exists ? SubscriptionModel.fromMap(c['id'] as String, subDoc.data() as Map<String, dynamic>) : null,
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
            : _companies.where((c) => (c['companyName'] as String).toLowerCase().contains(query.toLowerCase())).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double paddingValue = screenWidth < 600 ? 12.0 : 24.0;

    return Material(
      color: AdminColors.screenBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Expanded(
            child: _loadingCompanies
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(paddingValue, 0, paddingValue, 24),
                    child: Column(
                      children: [
                        _buildMetricsRow(),
                        const SizedBox(height: 24),
                        _buildFilterBar(),
                        const SizedBox(height: 20),
                        AdminCard(
                          padding: EdgeInsets.zero,
                          child: _filtered.isEmpty
                              ? const Padding(padding: EdgeInsets.all(80), child: AdminEmptyState(icon: Icons.business_rounded, message: 'No companies matching your search criteria.'))
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: _buildSubscriptionTable(),
                                ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final double screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.fromLTRB(screenWidth < 600 ? 12 : 24, 24, screenWidth < 600 ? 12 : 24, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 600) {
            return Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Corporate Subscriptions', style: AdminTheme.titleStyle(size: 24)),
                      const SizedBox(height: 4),
                      Text('Monitor service tiers, lifecycle status, and administrative grants.', style: AdminTheme.mutedStyle()),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _loadCompanies,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Sync Workspace'),
                  style: AdminTheme.primaryButtonStyle(),
                ),
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Corporate Subscriptions', style: AdminTheme.titleStyle(size: 20)),
                const SizedBox(height: 4),
                Text('Monitor service tiers and status.', style: AdminTheme.mutedStyle(size: 12)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _loadCompanies,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Sync Workspace'),
                  style: AdminTheme.primaryButtonStyle(),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildMetricsRow() {
    final basicCount = _subscriptions.values.where((s) => s?.plan == 'basic' && s!.isActive).length;
    final premiumCount = _subscriptions.values.where((s) => s?.plan == 'premium' && s!.isActive).length;
    final freeCount = _companies.length - basicCount - premiumCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final int crossAxisCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 550 ? 2 : 1);
        final double itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;
        final double childAspectRatio = itemWidth / 100;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: childAspectRatio,
          children: [
            _MetricTile(label: 'FREE TIERS', value: '$freeCount', icon: Icons.eco_outlined, color: AdminColors.textGrey),
            _MetricTile(label: 'BASIC PLANS', value: '$basicCount', icon: Icons.star_border_rounded, color: AdminColors.primary),
            _MetricTile(label: 'PREMIUM SEATS', value: '$premiumCount', icon: Icons.workspace_premium_outlined, color: AdminColors.amber),
            _MetricTile(label: 'TOTAL ENTITIES', value: '${_companies.length}', icon: Icons.business_rounded, color: AdminColors.navy),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AdminColors.border)),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearch,
        decoration: AdminTheme.inputDecoration(
          hintText: 'Search by legal company name...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AdminColors.textGrey),
        ),
      ),
    );
  }

  Widget _buildSubscriptionTable() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: const Color(0xFFF1F5F9)),
      child: DataTable(
        headingRowHeight: 48,
        dataRowMaxHeight: 64,
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
        horizontalMargin: 20,
        columnSpacing: 24,
        columns: [
          DataColumn(label: Text('CORPORATE ENTITY', style: AdminTheme.sectionHeaderStyle())),
          DataColumn(label: Text('SERVICE TIER', style: AdminTheme.sectionHeaderStyle())),
          DataColumn(label: Text('EXPIRATION', style: AdminTheme.sectionHeaderStyle())),
          DataColumn(label: Text('SYSTEM STATUS', style: AdminTheme.sectionHeaderStyle())),
          DataColumn(label: Text('MANAGEMENT', style: AdminTheme.sectionHeaderStyle())),
        ],
        rows: _filtered.map((company) {
          final id = company['id'] as String;
          final sub = _subscriptions[id];
          final name = company['companyName'] as String;
          final plan = sub?.plan ?? 'free';
          final expires = sub?.expiresAt;

          return DataRow(cells: [
            DataCell(
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AdminColors.primary.withValues(alpha: 0.08),
                    child: Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminColors.primary)),
                  ),
                  const SizedBox(width: 12),
                  Text(name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AdminColors.navy, fontSize: 13)),
                ],
              ),
            ),
            DataCell(_planChip(plan)),
            DataCell(Text(expires != null ? DateFormat('MMM d, yyyy').format(expires) : 'Perpetual', style: AdminTheme.bodyStyle(size: 13))),
            DataCell(StatusChip(status: sub?.isActive == true ? 'active' : 'suspended')),
            DataCell(
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.bolt_rounded, color: AdminColors.amber, size: 20),
                    onPressed: () => _showGrantMenu(company, id, plan),
                    tooltip: 'Administrative Override',
                  ),
                  if (plan != 'free')
                    IconButton(
                      icon: const Icon(Icons.no_accounts_rounded, color: AdminColors.red, size: 20),
                      onPressed: () => _revokeSubscription(id, name),
                      tooltip: 'Revoke License',
                    ),
                ],
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  void _showGrantMenu(Map<String, dynamic> company, String id, String current) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('License Provisioning', style: AdminTheme.titleStyle()),
              const SizedBox(height: 8),
              Text('Entity: ${company['companyName']}', style: AdminTheme.mutedStyle()),
              const SizedBox(height: 24),
              ...kPlans.where((p) => p.id != PlanId.free).map((p) => ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${p.durationDays} Days Duration'),
                trailing: current == p.planKey ? const Icon(Icons.check_circle, color: AdminColors.green) : const Icon(Icons.add_circle_outline),
                enabled: current != p.planKey,
                onTap: () {
                  Navigator.pop(ctx);
                  _showGrantDialog(company, id, p);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _showGrantDialog(Map<String, dynamic> company, String id, PlanDefinition plan) {
    final note = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Grant ${plan.name} License'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('This will manually override the entity\'s subscription status for ${plan.durationDays} days.', style: AdminTheme.bodyStyle()),
            const SizedBox(height: 20),
            TextField(controller: note, decoration: AdminTheme.inputDecoration(labelText: 'Administrative Justification', hintText: 'Reason for manual grant...'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              await context.read<SubscriptionViewModel>().adminGrantPlan(companyId: id, plan: plan, note: note.text);
              if (mounted) Navigator.pop(ctx);
              _loadCompanies();
            },
            child: const Text('CONFIRM GRANT'),
          ),
        ],
      ),
    );
  }

  void _revokeSubscription(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Enterprise Access'),
        content: Text('Revert $name to the Free Tier immediately? All premium features will be locked.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              await _firestore.collection('subscriptions').doc(id).update({'plan': 'free', 'status': 'active', 'expiresAt': null});
              await _firestore.collection('companies').doc(id).update({'plan': 'free', 'planExpiry': null, 'aiEnabled': false});
              if (mounted) Navigator.pop(ctx);
              _loadCompanies();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.red),
            child: const Text('CONFIRM REVOCATION'),
          ),
        ],
      ),
    );
  }

  Widget _planChip(String plan) {
    final color = plan == 'premium' ? AdminColors.amber : (plan == 'basic' ? AdminColors.primary : AdminColors.textGrey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(plan.toUpperCase(), style: GoogleFonts.plusJakartaSans(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AdminColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AdminTheme.sectionHeaderStyle(size: 9)),
              Icon(icon, color: color.withValues(alpha: 0.6), size: 16),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AdminColors.navy)),
        ],
      ),
    );
  }
}