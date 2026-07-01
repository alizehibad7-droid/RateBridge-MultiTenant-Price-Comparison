import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../shell/field_shell_view.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/route_names.dart';
import '../../../models/material_listing.dart';
import '../../../theme/field_theme.dart';
import '../../../utils/currency_formatter.dart';
import '../../../viewmodels/field_user/field_orders_viewmodel.dart';
import '../../../viewmodels/field_user/field_session_viewmodel.dart';
import '../chat/field_chat_thread_args.dart';
import '../widgets/field_material_card.dart';

class FieldPlaceOrderView extends StatefulWidget {
  final MaterialListing material;

  const FieldPlaceOrderView({super.key, required this.material});

  @override
  State<FieldPlaceOrderView> createState() => _FieldPlaceOrderViewState();
}

class _FieldPlaceOrderViewState extends State<FieldPlaceOrderView> {
  static const _appBarNavy = Color(0xFF1E326E);

  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _requiredDate;
  bool _showSuccess = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(_onFormChanged);
    _addressController.addListener(_onFormChanged);
  }

  void _onFormChanged() => setState(() {});

  @override
  void dispose() {
    _quantityController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _quantity => double.tryParse(_quantityController.text.trim()) ?? 0;

  double get _total => _quantity * widget.material.pricePerUnit;

  double get _commission => _total * AppConstants.commissionRate;

  double get _supplierReceives => _total - _commission;

  bool get _isFormValid =>
      _quantity >= 1 &&
      _addressController.text.trim().isNotEmpty &&
      _requiredDate != null;

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  void _incrementQuantity() {
    final current = _quantity <= 0 ? 0.0 : _quantity;
    _quantityController.text = _formatQuantity(current + 1);
  }

  void _decrementQuantity() {
    if (_quantity <= 1) return;
    _quantityController.text = _formatQuantity(_quantity - 1);
  }

  String _formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _requiredDate ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(data: FieldTheme.theme, child: child!);
      },
    );
    if (picked != null) {
      setState(() => _requiredDate = picked);
    }
  }

  void _navigateAfterOrderSuccess() {
    final shell = FieldShellScope.maybeOf(context);
    if (shell != null) {
      shell.switchTab(FieldShellScope.ordersTabIndex);
      context.pop();
      return;
    }
    context.go('${RouteNames.fieldHome}?tab=${FieldShellScope.ordersTabIndex}');
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_requiredDate == null) {
      setState(() => _submitError = 'Please select a required delivery date.');
      return;
    }

    setState(() => _submitError = null);

    final session = context.read<FieldSessionViewModel>();
    final uid = session.user?.uid;
    final companyId = session.companyId;
    final userName = session.user?.name ?? 'Field User';
    if (uid == null || companyId == null) return;

    final success =
        await context.read<FieldOrdersViewModel>().placeOrderFromListing(
              companyId: companyId,
              fieldUserUid: uid,
              fieldUserName: userName,
              fieldUserPhone: session.user?.phone,
              material: widget.material,
              quantity: _quantity,
              deliveryAddress: _addressController.text.trim(),
              requiredDate: _requiredDate!,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
            );

    if (!mounted) return;

    if (success) {
      setState(() => _showSuccess = true);
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      _navigateAfterOrderSuccess();
    } else {
      final msg = context.read<FieldOrdersViewModel>().errorMessage ??
          'Could not place order. Please try again.';
      setState(() => _submitError = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }

  void _messageSupplier() {
    final material = widget.material;
    context.push(
      RouteNames.fieldChatThread.replaceFirst(':orderId', material.supplierId),
      extra: FieldChatThreadArgs(
        supplierUid: material.supplierId,
        supplierName: material.supplierName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) {
      return Theme(
        data: FieldTheme.theme,
        child: Scaffold(
          backgroundColor: FieldColors.screenBackground,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(FieldSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: FieldColors.statusSuccess.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 40,
                      color: FieldColors.statusSuccess,
                    ),
                  ),
                  const SizedBox(height: FieldSpacing.lg),
                  Text(
                    'Order placed successfully',
                    style: FieldTypography.headlineMedium.copyWith(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: FieldSpacing.sm),
                  Text(
                    'The supplier has been notified and will respond shortly.',
                    textAlign: TextAlign.center,
                    style: FieldTypography.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final vm = context.watch<FieldOrdersViewModel>();
    final material = widget.material;
    final commissionPercent =
        (AppConstants.commissionRate * 100).toStringAsFixed(0);
    final canSubmit = _isFormValid && !vm.isSubmitting;

    return Theme(
      data: FieldTheme.theme,
      child: Scaffold(
        backgroundColor: FieldColors.screenBackground,
        appBar: AppBar(
          backgroundColor: _appBarNavy,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            'Place Order',
            style: FieldTypography.titleMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    _OrderSummaryCard(
                      material: material,
                      supplierInitials: _initials(material.supplierName),
                      showVerifiedChip: true,
                      onMessageSupplier: _messageSupplier,
                    ),
                    const SizedBox(height: 12),
                    _OrderDetailsCard(
                      unit: material.unit,
                      quantityController: _quantityController,
                      onDecrement: _decrementQuantity,
                      onIncrement: _incrementQuantity,
                      subtotal: _total,
                      addressController: _addressController,
                      requiredDate: _requiredDate,
                      onPickDate: _pickDate,
                      notesController: _notesController,
                    ),
                    const SizedBox(height: 12),
                    _PaymentSummaryCard(
                      totalAmount: _total,
                      commissionAmount: _commission,
                      supplierEarning: _supplierReceives,
                      commissionPercent: commissionPercent,
                    ),
                    if (_submitError != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBanner(message: _submitError!),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: canSubmit ? _submitOrder : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: FieldColors.accentAmber,
                        disabledBackgroundColor: FieldColors.borderSubtle,
                        foregroundColor: FieldColors.primaryNavy,
                        disabledForegroundColor: FieldColors.textMuted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: vm.isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: FieldColors.primaryNavy,
                              ),
                            )
                          : Text(
                              'Place Order — ${CurrencyFormatter.formatPKR(_total)}',
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Part 1: Order summary ───────────────────────────────────────────────────

class _SummaryDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: FieldColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: FieldTypography.bodyMedium.copyWith(
                fontSize: 12,
                color: FieldColors.textSecondary,
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final MaterialListing material;
  final String supplierInitials;
  final bool showVerifiedChip;
  final VoidCallback? onMessageSupplier;

  const _OrderSummaryCard({
    required this.material,
    required this.supplierInitials,
    required this.showVerifiedChip,
    this.onMessageSupplier,
  });

  @override
  Widget build(BuildContext context) {
    return _CheckoutCard(
      title: 'Order Summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: FieldColors.primaryNavy,
                child: Text(
                  supplierInitials,
                  style: FieldTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  material.supplierName,
                  style: FieldTypography.titleMedium.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: FieldColors.primaryNavy,
                  ),
                ),
              ),
              if (showVerifiedChip)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: FieldColors.statusSuccess.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Verified Supplier',
                    style: FieldTypography.labelSmall.copyWith(
                      color: FieldColors.statusSuccess,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          if (onMessageSupplier != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onMessageSupplier,
                icon: const Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                  color: FieldColors.primaryNavy,
                ),
                label: Text(
                  'Message supplier',
                  style: FieldTypography.bodyMedium.copyWith(
                    fontSize: 12,
                    color: FieldColors.primaryNavy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFE2E5F0)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: FieldColors.accentAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  fieldMaterialCategoryIcon(material.category),
                  color: FieldColors.primaryNavy,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      material.materialName,
                      style: FieldTypography.titleMedium.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: FieldColors.primaryNavy,
                      ),
                    ),
                    if (material.brandGradeSubtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        material.brandGradeSubtitle!,
                        style: FieldTypography.bodyMedium.copyWith(
                          fontSize: 12,
                          color: FieldColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      material.category,
                      style: FieldTypography.bodyMedium.copyWith(
                        fontSize: 12,
                        color: FieldColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${CurrencyFormatter.formatPKR(material.pricePerUnit)} / ${material.unit}',
                    textAlign: TextAlign.right,
                    style: FieldTypography.titleMedium.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: FieldColors.accentAmber,
                    ),
                  ),
                  if (material.minOrderLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      material.minOrderLabel!,
                      textAlign: TextAlign.right,
                      style: FieldTypography.labelSmall.copyWith(
                        fontSize: 10,
                        color: FieldColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (material.description?.trim().isNotEmpty == true) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFE2E5F0)),
            ),
            Text(
              material.description!.trim(),
              style: FieldTypography.bodyMedium.copyWith(
                fontSize: 13,
                color: FieldColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (material.hasDeliveryInfo) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFE2E5F0)),
            ),
            Text(
              'Delivery Information',
              style: FieldTypography.labelSmall.copyWith(
                color: FieldColors.primaryNavy,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            if (material.deliveryTime?.trim().isNotEmpty == true)
              _SummaryDetailRow(
                icon: Icons.schedule_outlined,
                label: 'Delivery time',
                value: material.deliveryTime!.trim(),
              ),
            if (material.deliveryCoverageArea?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 6),
              _SummaryDetailRow(
                icon: Icons.map_outlined,
                label: 'Coverage area',
                value: material.deliveryCoverageArea!.trim(),
              ),
            ],
            if (material.deliveryCharges?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 6),
              _SummaryDetailRow(
                icon: Icons.local_shipping_outlined,
                label: 'Delivery charges',
                value: material.deliveryCharges!.trim(),
              ),
            ],
          ],
          if (material.hasBulkDiscount) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFE2E5F0)),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.sell_outlined,
                  size: 16,
                  color: FieldColors.statusSuccess,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bulk discount available',
                        style: FieldTypography.labelSmall.copyWith(
                          color: FieldColors.statusSuccess,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        material.bulkDiscountDetails!.trim(),
                        style: FieldTypography.bodyMedium.copyWith(
                          fontSize: 12,
                          color: FieldColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
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

// ─── Part 2: Order details form ──────────────────────────────────────────────

class _OrderDetailsCard extends StatelessWidget {
  final String unit;
  final TextEditingController quantityController;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final double subtotal;
  final TextEditingController addressController;
  final DateTime? requiredDate;
  final VoidCallback onPickDate;
  final TextEditingController notesController;

  const _OrderDetailsCard({
    required this.unit,
    required this.quantityController,
    required this.onDecrement,
    required this.onIncrement,
    required this.subtotal,
    required this.addressController,
    required this.requiredDate,
    required this.onPickDate,
    required this.notesController,
  });

  @override
  Widget build(BuildContext context) {
    return _CheckoutCard(
      title: 'Order Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Quantity',
                style: FieldTypography.labelSmall.copyWith(
                  color: FieldColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '($unit)',
                style: FieldTypography.bodyMedium.copyWith(
                  fontSize: 12,
                  color: FieldColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _QtyCircleButton(
                icon: Icons.remove,
                onTap: onDecrement,
              ),
              Expanded(
                child: TextFormField(
                  controller: quantityController,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  style: FieldTypography.headlineMedium.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: FieldColors.primaryNavy,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  validator: (value) {
                    final qty = double.tryParse(value?.trim() ?? '');
                    if (qty == null || qty < 1) {
                      return 'Enter a quantity of at least 1';
                    }
                    return null;
                  },
                ),
              ),
              _QtyCircleButton(
                icon: Icons.add,
                onTap: onIncrement,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: FieldColors.accentAmber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Subtotal: ${CurrencyFormatter.formatPKR(subtotal)}',
              style: FieldTypography.titleMedium.copyWith(
                color: FieldColors.accentAmber,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Delivery Site Address',
            style: FieldTypography.labelSmall.copyWith(
              color: FieldColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: addressController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter full delivery address...',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Delivery address is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Required By',
            style: FieldTypography.labelSmall.copyWith(
              color: FieldColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(FieldRadius.input),
            child: InputDecorator(
              decoration: const InputDecoration(
                hintText: 'Select delivery date',
                suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
              ),
              child: Text(
                requiredDate == null
                    ? 'Tap to choose a date'
                    : MaterialLocalizations.of(context)
                        .formatMediumDate(requiredDate!),
                style: requiredDate == null
                    ? FieldTypography.bodyMedium.copyWith(
                        color: FieldColors.textMuted,
                      )
                    : FieldTypography.bodyLarge.copyWith(
                        color: FieldColors.primaryNavy,
                        fontWeight: FontWeight.w700,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Additional Notes (optional)',
            style: FieldTypography.labelSmall.copyWith(
              color: FieldColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: notesController,
            maxLines: 1,
            decoration: const InputDecoration(
              hintText: 'Any special instructions...',
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: FieldColors.primaryNavy),
          ),
          child: Icon(icon, size: 18, color: FieldColors.primaryNavy),
        ),
      ),
    );
  }
}

// ─── Part 3: Payment summary ─────────────────────────────────────────────────

class _PaymentSummaryCard extends StatelessWidget {
  final double totalAmount;
  final double commissionAmount;
  final double supplierEarning;
  final String commissionPercent;

  const _PaymentSummaryCard({
    required this.totalAmount,
    required this.commissionAmount,
    required this.supplierEarning,
    required this.commissionPercent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FieldColors.accentAmber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: FieldColors.accentAmber.withValues(alpha: 0.45),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Payment Summary',
            style: FieldTypography.titleMedium.copyWith(
              color: FieldColors.accentAmber,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          _PaymentRow(
            label: 'Order Total',
            value: CurrencyFormatter.formatPKR(totalAmount),
            valueColor: FieldColors.primaryNavy,
            valueWeight: FontWeight.w700,
          ),
          const SizedBox(height: 8),
          _PaymentRow(
            label: 'Commission ($commissionPercent%)',
            value: '– ${CurrencyFormatter.formatPKR(commissionAmount)}',
            valueColor: FieldColors.statusDanger,
          ),
          const SizedBox(height: 8),
          _PaymentRow(
            label: 'Supplier Gets',
            value: CurrencyFormatter.formatPKR(supplierEarning),
            valueColor: FieldColors.statusSuccess,
            valueWeight: FontWeight.w700,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFE2E5F0)),
          ),
          Text(
            'Payment is made directly to supplier upon delivery',
            style: FieldTypography.bodyMedium.copyWith(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: FieldColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final FontWeight valueWeight;

  const _PaymentRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.valueWeight = FontWeight.w400,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: FieldTypography.bodyMedium.copyWith(fontSize: 13)),
        Text(
          value,
          style: FieldTypography.bodyMedium.copyWith(
            fontSize: 13,
            color: valueColor,
            fontWeight: valueWeight,
          ),
        ),
      ],
    );
  }
}

// ─── Shared widgets ────────────────────────────────────────────────────────────

class _CheckoutCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _CheckoutCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E5F0)),
        boxShadow: [
          BoxShadow(
            color: FieldColors.primaryNavy.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: FieldTypography.titleMedium.copyWith(
              color: FieldColors.primaryNavy,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FieldColors.statusDanger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FieldColors.statusDanger.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 18,
            color: FieldColors.statusDanger,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: FieldTypography.bodyMedium.copyWith(
                color: FieldColors.statusDanger,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
