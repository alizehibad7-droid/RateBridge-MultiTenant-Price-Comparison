import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../constants/route_names.dart';
import '../../../models/rfq_model.dart';
import '../../../theme/supplier_theme.dart';
import '../../../viewmodels/supplier_viewmodel.dart';
import '../../../widgets/supplier_nav_bar.dart';

class SupplierRfqListView extends StatelessWidget {
  const SupplierRfqListView({super.key});

  @override
  Widget build(BuildContext context) {
    final supplierVM = context.watch<SupplierViewModel>();

    return Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: const SupplierAppBar(title: 'Open Quote Requests'),
      body: StreamBuilder<List<RfqModel>>(
        stream: supplierVM.streamOpenRfqsForSupplier(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final rfqs = snapshot.data ?? [];

          if (rfqs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.request_quote_outlined, size: 64, color: FieldColors.textMuted.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('No open requests matching you', style: FieldTypography.titleMedium),
                  const SizedBox(height: 8),
                  Text('Requests will appear here when companies look for materials in your categories and area.', textAlign: TextAlign.center, style: FieldTypography.bodyMedium),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rfqs.length,
            itemBuilder: (context, index) => _SupplierRfqTile(rfq: rfqs[index]),
          );
        },
      ),
      bottomNavigationBar: const SupplierNavBar(currentIndex: 2), // Example index
    );
  }
}

class _SupplierRfqTile extends StatelessWidget {
  final RfqModel rfq;
  const _SupplierRfqTile({required this.rfq});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: SupplierTheme.cardDecoration(),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(rfq.category, style: FieldTypography.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(rfq.materialDescription, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Row(
              children: [
                _Badge(icon: Icons.numbers, label: '${rfq.quantity} ${rfq.unit}'),
                const SizedBox(width: 8),
                _Badge(icon: Icons.location_on, label: rfq.city),
              ],
            ),
            const SizedBox(height: 8),
            Text('Ends: ${DateFormat('MMM dd').format(rfq.requiredByDate)}', style: FieldTypography.labelSmall),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(RouteNames.supplierSubmitBid.replaceFirst(':rfqId', rfq.id)),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Badge({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: FieldColors.primaryNavy.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: FieldColors.primaryNavy),
          const SizedBox(width: 4),
          Text(label, style: FieldTypography.labelSmall.copyWith(color: FieldColors.primaryNavy)),
        ],
      ),
    );
  }
}
