import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../../../widgets/ceo/ceo_widgets.dart';

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
      appBar: CeoAppBar(
        title: fieldUser ? 'Bulk Quotes' : 'Request for Quotations',
      ),
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
        backgroundColor: CeoColors.navy,
        icon: const Icon(Icons.add_circle_rounded, color: Colors.white),
        label: Text(
          'CREATE RFQ',
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5),
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: CeoColors.navy.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.request_quote_rounded,
              size: 64,
              color: CeoColors.textGrey,
            ),
          ),
          const SizedBox(height: 24),
          Text('No active RFQs', style: CeoTheme.titleStyle(size: 20)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Get competitive bulk pricing by requesting quotes from multiple suppliers at once.',
              textAlign: TextAlign.center,
              style: CeoTheme.mutedStyle(),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: CeoColors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CeoColors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_rounded, color: CeoColors.darkAmber, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Premium Feature',
                  style: GoogleFonts.plusJakartaSans(
                    color: CeoColors.darkAmber,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
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
            title: Row(
              children: [
                const Icon(Icons.workspace_premium_rounded, color: CeoColors.amber),
                const SizedBox(width: 10),
                const Text('Premium Access'),
              ],
            ),
            content: Text(
              fieldUser
                  ? 'Bulk Quote Requests (RFQ) are only available on the Premium plan. Please ask your CEO to upgrade the company workspace.'
                  : 'Bulk Quote Requests (RFQ) are only available on the Premium plan. Upgrade now to start receiving competitive bids and save on materials.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(fieldUser ? 'CLOSE' : 'MAYBE LATER'),
              ),
              if (!fieldUser)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(RouteNames.ceoSubscription);
                  },
                  icon: const Icon(Icons.upgrade_rounded),
                  label: const Text('UPGRADE NOW'),
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
    final isOpen = rfq.status == 'open';
    final statusColor = isOpen ? CeoColors.green : CeoColors.textGrey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: CeoTheme.cardDecoration(),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: CeoColors.navy.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.request_quote_rounded, color: CeoColors.navy, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                rfq.category,
                style: CeoTheme.titleStyle(size: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(isOpen ? Icons.bolt_rounded : Icons.lock_clock_rounded, size: 10, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    rfq.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(
              rfq.materialDescription,
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500, color: CeoColors.navy),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _iconDetail(Icons.inventory_2_outlined, '${rfq.quantity} ${rfq.unit}'),
                const SizedBox(width: 12),
                _iconDetail(Icons.location_on_outlined, rfq.city),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.event_note_rounded, size: 12, color: CeoColors.textGrey),
                const SizedBox(width: 6),
                Text(
                  'Deadline: ${DateFormat('MMM dd, yyyy').format(rfq.requiredByDate)}',
                  style: CeoTheme.mutedStyle(size: 12).copyWith(
                    color: rfq.requiredByDate.isBefore(DateTime.now()) ? CeoColors.red : null,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: CeoColors.textGrey),
        onTap: () => context.push(detailRoute.replaceFirst(':rfqId', rfq.id)),
      ),
    );
  }

  Widget _iconDetail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: CeoColors.textGrey),
        const SizedBox(width: 4),
        Text(text, style: CeoTheme.mutedStyle(size: 12)),
      ],
    );
  }
}
