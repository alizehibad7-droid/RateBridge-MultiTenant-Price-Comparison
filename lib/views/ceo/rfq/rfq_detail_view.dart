import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/rfq_model.dart';
import '../../../models/rfq_bid_model.dart';
import '../../../services/firestore_service.dart';
import '../../../theme/ceo_theme.dart';
import '../../../utils/currency_formatter.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/rfq_viewmodel.dart';

class RfqDetailView extends StatelessWidget {
  final String rfqId;
  const RfqDetailView({super.key, required this.rfqId});

  @override
  Widget build(BuildContext context) {
    final rfqVM = context.read<RfqViewModel>();

    return Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: const CeoAppBar(title: 'RFQ Details'),
      body: StreamBuilder<RfqModel?>(
        stream: rfqVM.watchRfq(rfqId),
        builder: (context, rfqSnap) {
          if (rfqSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rfq = rfqSnap.data;
          if (rfq == null) {
            return const Center(child: Text('RFQ not found'));
          }

          return StreamBuilder<List<RfqBidModel>>(
            stream: rfqVM.watchRfqBids(rfqId),
            builder: (context, bidsSnap) {
              final bids = bidsSnap.data ?? [];

              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildRfqHeader(rfq),
                  const SizedBox(height: 32),
                  CeoSectionLabel('Supplier Bids (${bids.length})'),
                  const SizedBox(height: 16),
                  if (bids.isEmpty)
                    _buildNoBidsState()
                  else
                    ...bids.map((bid) => _BidCard(rfq: rfq, bid: bid)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRfqHeader(RfqModel rfq) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: CeoTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                rfq.category.toUpperCase(),
                style: CeoTheme.sectionHeaderStyle(),
              ),
              _StatusBadge(status: rfq.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(rfq.materialDescription, style: CeoTheme.titleStyle(size: 20)),
          const Divider(height: 32),
          Row(
            children: [
              _InfoItem(
                label: 'Quantity',
                value: '${rfq.quantity} ${rfq.unit}',
                icon: Icons.numbers,
              ),
              _InfoItem(
                label: 'City',
                value: rfq.city,
                icon: Icons.location_on,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _InfoItem(
                label: 'Required By',
                value: DateFormat('MMM dd, yyyy').format(rfq.requiredByDate),
                icon: Icons.calendar_today,
              ),
              _InfoItem(
                label: 'Published',
                value: DateFormat('MMM dd').format(rfq.createdAt),
                icon: Icons.access_time,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoBidsState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: CeoTheme.cardDecoration(),
      child: Column(
        children: [
          Icon(
            Icons.hourglass_empty,
            color: CeoColors.textGrey.withOpacity(0.3),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text('Waiting for bids...', style: CeoTheme.mutedStyle()),
          const SizedBox(height: 8),
          Text(
            'Matching suppliers have been notified.',
            textAlign: TextAlign.center,
            style: CeoTheme.mutedStyle(size: 12),
          ),
        ],
      ),
    );
  }
}

class _BidCard extends StatelessWidget {
  final RfqModel rfq;
  final RfqBidModel bid;
  const _BidCard({required this.rfq, required this.bid});

  Future<void> _award(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Award Quote?'),
            content: Text(
              'This will close the RFQ and create a new order with ${bid.supplierName} for ${CurrencyFormatter.formatPKR(bid.bidPrice * rfq.quantity)}.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx, true);
                },
                child: const Text('AWARD'),
              ),
            ],
          ),
    );
    if (confirmed != true || !context.mounted) return;

    final ceoUid = context.read<AuthViewModel>().user!.uid;
    final rfqVM = context.read<RfqViewModel>();
    await rfqVM.awardRfq(rfq: rfq, bid: bid, ceoUid: ceoUid);
    if (!context.mounted) return;
    if (rfqVM.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(rfqVM.error!), backgroundColor: CeoColors.red),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quote awarded and order created.'),
        backgroundColor: CeoColors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAwarded = rfq.awardedBidId == bid.id;
    final user = context.watch<AuthViewModel>().user;
    final role = user?.role.toLowerCase().replaceAll('_', '') ?? '';
    final canAward =
        rfq.status == 'open' &&
        (role == 'ceo' || rfq.createdByUid == user?.uid);
    final rfqVM = context.watch<RfqViewModel>();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: CeoTheme.cardDecoration(
        borderColor: isAwarded ? CeoColors.green : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: CeoColors.amber.withOpacity(0.1),
                  child: const Icon(Icons.store, color: CeoColors.amber),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bid.supplierName,
                        style: CeoTheme.titleStyle(size: 16),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: CeoColors.amber, size: 14),
                          StreamBuilder<double>(
                            stream: context
                                .read<FirestoreService>()
                                .streamSupplierRating(bid.supplierId),
                            initialData: bid.supplierRating,
                            builder:
                                (context, snapshot) => Text(
                                  ' ${(snapshot.data ?? bid.supplierRating).toStringAsFixed(1)}',
                                  style: CeoTheme.mutedStyle(size: 12),
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.formatPKR(bid.bidPrice),
                  style: CeoTheme.titleStyle(size: 18),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _InfoItem(
                  label: 'Delivery',
                  value: bid.estimatedDeliveryTime,
                  icon: Icons.local_shipping_outlined,
                ),
                _InfoItem(
                  label: 'Total',
                  value: CurrencyFormatter.formatPKR(
                    bid.bidPrice * rfq.quantity,
                  ),
                  icon: Icons.payments_outlined,
                ),
              ],
            ),
            if (bid.note != null && bid.note!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CeoColors.screenBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(bid.note!, style: CeoTheme.mutedStyle(size: 12)),
              ),
            ],
            if (canAward) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: rfqVM.isLoading ? null : () => _award(context),
                style: CeoTheme.primaryButtonStyle(height: 40),
                child:
                    rfqVM.isLoading
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text('AWARD CONTRACT'),
              ),
            ] else if (isAwarded) ...[
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: CeoColors.green, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'AWARDED',
                    style: TextStyle(
                      color: CeoColors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _InfoItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: CeoColors.textGrey),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: CeoTheme.mutedStyle(size: 10)),
              Text(
                value,
                style: CeoTheme.bodyStyle(
                  color: CeoColors.navy,
                ).copyWith(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = status == 'open' ? CeoColors.green : CeoColors.textGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
