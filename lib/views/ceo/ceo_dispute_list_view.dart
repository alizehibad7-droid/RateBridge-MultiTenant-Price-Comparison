import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/dispute_model.dart';
import '../../theme/ceo_theme.dart';
import '../../widgets/admin/admin_widgets.dart';
import '../../utils/chat_image_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../viewmodels/dispute_viewmodel.dart';

class CeoDisputeListView extends StatelessWidget {
  const CeoDisputeListView({super.key});

  @override
  Widget build(BuildContext context) {
    final companyId =
        context.watch<CeoViewModel>().company?.id ??
        context.watch<AuthViewModel>().user?.companyId ??
        '';
    final disputeVM = context.read<DisputeViewModel>();

    return Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: const CeoAppBar(title: 'Reported Issues'),
      body:
          companyId.isEmpty
              ? const Center(
                child: Text('Company account could not be resolved.'),
              )
              : StreamBuilder<List<DisputeModel>>(
                stream: disputeVM.watchCompanyDisputes(companyId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Could not load reported issues: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  final disputes =
                      (snapshot.data ?? [])
                          .where((dispute) => dispute.companyId == companyId)
                          .toList();

                  if (disputes.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.report_gmailerrorred_outlined,
                            size: 64,
                            color: CeoColors.textGrey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No reported issues found',
                            style: CeoTheme.titleStyle(),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: disputes.length,
                    itemBuilder:
                        (context, index) =>
                            _DisputeCard(dispute: disputes[index]),
                  );
                },
              ),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  final DisputeModel dispute;
  const _DisputeCard({required this.dispute});

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(dispute.status);
    return AdminCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dispute.type.label,
                    style: CeoTheme.titleStyle(size: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    dispute.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(dispute.description, style: CeoTheme.bodyStyle()),
            if (dispute.photoUrl != null && dispute.photoUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap:
                    () => ChatImageUtils.showFullscreen(
                      context,
                      imageUrl: dispute.photoUrl,
                    ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    dispute.photoUrl!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => const SizedBox(
                          height: 100,
                          child: Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                  ),
                ),
              ),
            ],
            if (dispute.resolutionNotes != null &&
                dispute.resolutionNotes!.isNotEmpty) ...[
              const Divider(height: 32),
              Text('RESOLUTION NOTES', style: CeoTheme.sectionHeaderStyle()),
              const SizedBox(height: 8),
              Text(
                dispute.resolutionNotes!,
                style: CeoTheme.bodyStyle(color: CeoColors.green),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Order: ${dispute.orderId} • ${DateFormat('MMM dd').format(dispute.createdAt)}',
              style: CeoTheme.mutedStyle(size: 11),
            ),
          ],
        ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'open':
        return CeoColors.red;
      case 'under_review':
        return CeoColors.amber;
      case 'resolved':
        return CeoColors.green;
      default:
        return CeoColors.textGrey;
    }
  }
}
