import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../constants/route_names.dart';
import '../../../models/rfq_model.dart';
import '../../../services/plan_limit_service.dart';
import '../../../theme/ceo_theme.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/ceo_viewmodel.dart';
import '../../../viewmodels/rfq_viewmodel.dart';
import '../../../widgets/ceo_nav_bar.dart';

class CeoRfqListView extends StatelessWidget {
  final bool fieldUser;

  const CeoRfqListView({super.key, this.fieldUser = false});

  @override
  Widget build(BuildContext context) {
    final company = context.watch<CeoViewModel>().company;
    final companyId =
        company?.id ?? context.watch<AuthViewModel>().user?.companyId ?? '';

    return Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: const CeoAppBar(title: 'Bulk Quote Requests (RFQ)'),
      body:
          companyId.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<List<RfqModel>>(
                stream: context.read<RfqViewModel>().watchCompanyRfqs(
                  companyId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rfqs = snapshot.data ?? [];

                  if (rfqs.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rfqs.length,
                    itemBuilder:
                        (context, index) => _RfqTile(
                          rfq: rfqs[index],
                          detailRoute:
                              fieldUser
                                  ? RouteNames.fieldRfqDetail
                                  : RouteNames.ceoRfqDetail,
                        ),
                  );
                },
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final effectivePlan = await PlanLimitService.companyPlan(
            FirebaseFirestore.instance,
            companyId,
          );
          if (!context.mounted) return;
          if (effectivePlan.planKey != 'premium') {
            _showPremiumRequiredDialog(context);
          } else {
            context.push(
              fieldUser ? RouteNames.fieldCreateRfq : RouteNames.ceoCreateRfq,
            );
          }
        },
        backgroundColor: CeoColors.amber,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Request',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      bottomNavigationBar: fieldUser ? null : const CeoNavBar(currentIndex: 2),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.request_page_outlined,
            size: 64,
            color: CeoColors.textGrey.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text('No quote requests yet', style: CeoTheme.titleStyle(size: 18)),
          const SizedBox(height: 8),
          Text(
            'Get bulk pricing by requesting quotes from suppliers.',
            style: CeoTheme.mutedStyle(),
          ),
          const SizedBox(height: 24),
          Text(
            '✨ Premium Feature',
            style: TextStyle(
              color: CeoColors.amber,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showPremiumRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Premium Feature'),
            content: Text(
              fieldUser
                  ? 'Bulk Quote Requests are only available on the Premium plan. Ask your CEO to upgrade the company plan.'
                  : 'Bulk Quote Requests (RFQ) are only available on the Premium plan. Upgrade to start receiving competitive bids from suppliers.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(fieldUser ? 'CLOSE' : 'MAYBE LATER'),
              ),
              if (!fieldUser)
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(RouteNames.ceoSubscription);
                  },
                  child: const Text('UPGRADE NOW'),
                ),
            ],
          ),
    );
  }
}

class _RfqTile extends StatelessWidget {
  final RfqModel rfq;
  final String detailRoute;
  const _RfqTile({required this.rfq, required this.detailRoute});

  @override
  Widget build(BuildContext context) {
    final statusColor =
        rfq.status == 'open' ? CeoColors.green : CeoColors.textGrey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CeoTheme.cardDecoration(),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Expanded(
              child: Text(rfq.category, style: CeoTheme.titleStyle(size: 16)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                rfq.status.toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              rfq.materialDescription,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${rfq.quantity} ${rfq.unit} • ${rfq.city}',
              style: CeoTheme.mutedStyle(),
            ),
            const SizedBox(height: 4),
            Text(
              'Required by: ${DateFormat('MMM dd, yyyy').format(rfq.requiredByDate)}',
              style: CeoTheme.mutedStyle(),
            ),
          ],
        ),
        onTap: () => context.push(detailRoute.replaceFirst(':rfqId', rfq.id)),
      ),
    );
  }
}
