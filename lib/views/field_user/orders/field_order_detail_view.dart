import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/app_constants.dart';
import '../../../constants/route_names.dart';
import '../../../models/order_model.dart';
import '../../../theme/field_theme.dart';
import '../../../viewmodels/field_user/field_orders_viewmodel.dart';
import '../../../widgets/order_status_stepper_widget.dart';
import '../widgets/field_async_states.dart';
import '../chat/field_chat_thread_args.dart';
import 'field_order_status.dart';

class FieldOrderDetailView extends StatefulWidget {
  final OrderModel? order;
  final String? orderId;

  const FieldOrderDetailView({
    super.key,
    this.order,
    this.orderId,
  }) : assert(order != null || orderId != null,
            'Provide either order or orderId');

  @override
  State<FieldOrderDetailView> createState() => _FieldOrderDetailViewState();
}

class _FieldOrderDetailViewState extends State<FieldOrderDetailView> {
  OrderModel? _order;
  String? _supplierPhone;
  bool? _hasRating;
  bool _isLoading = true;
  bool _isConfirming = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _isLoading = widget.order == null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (widget.order == null) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    } else {
      setState(() => _loadError = null);
    }

    final vm = context.read<FieldOrdersViewModel>();

    try {
      if (_order == null && widget.orderId != null) {
        _order = await vm.fetchOrder(widget.orderId!);
        if (_order == null) {
          setState(() {
            _loadError = 'Order not found';
            _isLoading = false;
          });
          return;
        }
      }

      if (_order == null) {
        setState(() {
          _loadError = 'Order not found';
          _isLoading = false;
        });
        return;
      }

      final supplier = await vm.fetchSupplier(_order!.supplierId);
      _supplierPhone = supplier?.contact;

      if (FieldOrderStatus.canRate(_order!.status)) {
        _hasRating = await vm.hasRatingForOrder(
          _order!.orderId,
          _order!.companyId,
        );
      }
    } catch (e) {
      _loadError = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelOrder() async {
    final order = _order;
    if (order == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel order?'),
        content: const Text(
          'This order will be cancelled. You can place a new order anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep order'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await context.read<FieldOrdersViewModel>().cancelOrder(
          order.orderId,
          order.companyId,
        );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<FieldOrdersViewModel>().errorMessage ??
                'Could not cancel order',
          ),
        ),
      );
    }
  }

  Future<void> _callSupplier() async {
    final phone = _supplierPhone?.trim();
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier phone number not available')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialer')),
        );
      }
    }
  }

  void _messageSupplier() {
    final order = _order;
    if (order == null) return;
    context.push(
      RouteNames.fieldChatThread.replaceFirst(':orderId', order.supplierId),
      extra: FieldChatThreadArgs(
        supplierUid: order.supplierId,
        supplierName: order.supplierName,
        orderId: order.orderId,
      ),
    );
  }

  void _openRateSupplier() {
    final order = _order;
    if (order == null) return;
    context.push(
      RouteNames.fieldRateSupplier.replaceFirst(':orderId', order.orderId),
      extra: order,
    ).then((_) => _load());
  }

  void _openSupplierProfile() {
    final order = _order;
    if (order == null) return;
    context.push(
      RouteNames.fieldSupplierProfile.replaceFirst(
        ':supplierUid',
        order.supplierId,
      ),
    );
  }

  Future<void> _confirmDelivery() async {
    final order = _order;
    if (order == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FieldRadius.card),
        ),
        title: Text(
          'Confirm delivery?',
          style: FieldTypography.titleMedium,
        ),
        content: Text(
          'Have you received the material and paid the supplier in cash?',
          style: FieldTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: FieldColors.accentAmber,
              foregroundColor: FieldColors.primaryNavy,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FieldRadius.button),
              ),
            ),
            child: const Text('Yes, Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isConfirming = true);
    final success = await context.read<FieldOrdersViewModel>().confirmDelivery(
          orderId: order.orderId,
          companyId: order.companyId,
        );
    if (!mounted) return;
    setState(() => _isConfirming = false);

    if (success) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Delivery confirmed successfully'),
            backgroundColor: FieldColors.statusSuccess,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FieldRadius.input),
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<FieldOrdersViewModel>().errorMessage ??
                  'Could not confirm delivery',
            ),
            backgroundColor: FieldColors.statusDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  ({double total, double commission, double supplierReceives})
      _commissionBreakdown(OrderModel order) {
    final total = order.totalAmount;
    final commission = order.commissionAmount > 0
        ? order.commissionAmount
        : total * AppConstants.commissionRate;
    final supplierReceives = order.supplierEarning > 0
        ? order.supplierEarning
        : total - commission;
    return (total: total, commission: commission, supplierReceives: supplierReceives);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FieldTheme.theme,
      child: Scaffold(
        backgroundColor: FieldColors.screenBackground,
        appBar: const FieldAppBar(title: 'Order detail'),
        body: _isLoading
            ? const _OrderDetailSkeleton()
            : _loadError != null
                ? FieldErrorState(
                    title: 'Could not load order',
                    message: _loadError!,
                    onRetry: _load,
                  )
                : _buildContent(_order!),
      ),
    );
  }

  Widget _buildContent(OrderModel order) {
    final vm = context.watch<FieldOrdersViewModel>();
    final dateFmt = DateFormat('MMM d, yyyy');
    final breakdown = _commissionBreakdown(order);
    final commissionPercent =
        (AppConstants.commissionRate * 100).toStringAsFixed(0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        FieldSpacing.lg,
        FieldSpacing.sm,
        FieldSpacing.lg,
        FieldSpacing.xxl,
      ),
      children: [
        OrderStatusStepperWidget(status: order.status),
        const SizedBox(height: FieldSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(FieldSpacing.md),
          decoration: FieldTheme.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Order summary', style: FieldTypography.titleMedium),
              const SizedBox(height: FieldSpacing.md),
              _SummaryRow(label: 'Material', value: order.materialName),
              _SummaryRow(
                label: 'Quantity',
                value: '${order.quantity.toStringAsFixed(order.quantity.truncateToDouble() == order.quantity ? 0 : 1)} ${order.unit}',
              ),
              _SummaryRow(
                label: 'Unit price',
                value: 'Rs ${order.unitPrice.toStringAsFixed(0)}',
              ),
              const Divider(height: FieldSpacing.lg),
              _SummaryRow(label: 'Delivery address', value: order.deliveryAddress),
              if (order.requiredDate != null)
                _SummaryRow(
                  label: 'Required date',
                  value: dateFmt.format(order.requiredDate!),
                ),
              const Divider(height: FieldSpacing.lg),
              _SummaryRow(label: 'Supplier', value: order.supplierName),
              if (_supplierPhone != null && _supplierPhone!.isNotEmpty)
                _SummaryRow(label: 'Supplier phone', value: _supplierPhone!),
              if (order.notes != null && order.notes!.isNotEmpty)
                _SummaryRow(label: 'Notes', value: order.notes!),
            ],
          ),
        ),
        const SizedBox(height: FieldSpacing.lg),
        _CommissionBreakdownCard(
          total: breakdown.total,
          commission: breakdown.commission,
          supplierReceives: breakdown.supplierReceives,
          commissionPercent: commissionPercent,
          isSettled: order.commissionDeducted,
        ),
        const SizedBox(height: FieldSpacing.lg),
        OutlinedButton.icon(
          onPressed: _openSupplierProfile,
          icon: const Icon(Icons.store_outlined, size: 18),
          label: const Text('View supplier profile'),
        ),
        const SizedBox(height: FieldSpacing.sm),
        OutlinedButton.icon(
          onPressed: _messageSupplier,
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          label: const Text('Message Supplier'),
        ),
        const SizedBox(height: FieldSpacing.sm),
        OutlinedButton.icon(
          onPressed: _callSupplier,
          icon: const Icon(Icons.phone_outlined, size: 18),
          label: const Text('Call supplier'),
        ),
        if (FieldOrderStatus.canConfirmDelivery(order.status)) ...[
          const SizedBox(height: FieldSpacing.lg),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _isConfirming ? null : _confirmDelivery,
              style: FilledButton.styleFrom(
                backgroundColor: FieldColors.accentAmber,
                foregroundColor: FieldColors.textPrimary,
                disabledBackgroundColor:
                    FieldColors.accentAmber.withValues(alpha: 0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FieldRadius.button),
                ),
              ),
              icon: _isConfirming
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FieldColors.textPrimary,
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 22),
              label: Text(
                _isConfirming ? 'Confirming...' : 'Confirm Delivery',
                style: FieldTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        if (FieldOrderStatus.canRate(order.status) && _hasRating == false) ...[
          const SizedBox(height: FieldSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openRateSupplier,
              icon: const Icon(Icons.star_outline, size: 18),
              label: const Text('Rate this delivery'),
            ),
          ),
        ],
        if (FieldOrderStatus.canCancel(order.status)) ...[
          const SizedBox(height: FieldSpacing.lg),
          OutlinedButton(
            onPressed: vm.isSubmitting ? null : _cancelOrder,
            style: OutlinedButton.styleFrom(
              foregroundColor: FieldColors.statusDanger,
              side: BorderSide(
                color: FieldColors.statusDanger.withValues(alpha: 0.4),
              ),
            ),
            child: vm.isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Cancel order'),
          ),
        ],
      ],
    );
  }
}

class _CommissionBreakdownCard extends StatelessWidget {
  final double total;
  final double commission;
  final double supplierReceives;
  final String commissionPercent;
  final bool isSettled;

  const _CommissionBreakdownCard({
    required this.total,
    required this.commission,
    required this.supplierReceives,
    required this.commissionPercent,
    required this.isSettled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FieldSpacing.md),
      decoration: BoxDecoration(
        color: FieldColors.accentAmber.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(FieldRadius.card),
        border: Border.all(
          color: FieldColors.accentAmber,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 18,
                color: FieldColors.statusWarning,
              ),
              const SizedBox(width: FieldSpacing.sm),
              Text(
                'Commission breakdown',
                style: FieldTypography.titleMedium.copyWith(
                  color: FieldColors.primaryNavy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: FieldSpacing.md),
          _BreakdownLine(
            label: 'Order total',
            value: 'Rs ${total.toStringAsFixed(0)}',
            emphasized: true,
          ),
          const SizedBox(height: FieldSpacing.sm),
          _BreakdownLine(
            label: 'Platform commission ($commissionPercent%)',
            value: 'Rs ${commission.toStringAsFixed(0)}',
          ),
          const SizedBox(height: FieldSpacing.sm),
          _BreakdownLine(
            label: 'Supplier receives',
            value: 'Rs ${supplierReceives.toStringAsFixed(0)}',
            emphasized: true,
          ),
          if (isSettled) ...[
            const SizedBox(height: FieldSpacing.md),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: FieldColors.statusSuccess,
                ),
                const SizedBox(width: FieldSpacing.xs),
                Text(
                  'Commission recorded',
                  style: FieldTypography.labelSmall.copyWith(
                    color: FieldColors.statusSuccess,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BreakdownLine extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _BreakdownLine({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: emphasized
                ? FieldTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  )
                : FieldTypography.bodyMedium,
          ),
        ),
        Text(
          value,
          style: emphasized
              ? FieldTypography.titleMedium.copyWith(
                  color: FieldColors.primaryNavy,
                )
              : FieldTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FieldSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: FieldTypography.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              style: FieldTypography.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderDetailSkeleton extends StatelessWidget {
  const _OrderDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(FieldSpacing.lg),
      children: [
        Shimmer.fromColors(
          baseColor: FieldColors.borderSubtle,
          highlightColor: FieldColors.surfaceWhite,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: FieldColors.borderSubtle,
              borderRadius: BorderRadius.circular(FieldRadius.card),
            ),
          ),
        ),
        const SizedBox(height: FieldSpacing.lg),
        Shimmer.fromColors(
          baseColor: FieldColors.borderSubtle,
          highlightColor: FieldColors.surfaceWhite,
          child: Container(
            height: 280,
            decoration: BoxDecoration(
              color: FieldColors.borderSubtle,
              borderRadius: BorderRadius.circular(FieldRadius.card),
            ),
          ),
        ),
      ],
    );
  }
}
