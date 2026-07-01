import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/order_model.dart';
import '../../../theme/field_theme.dart';
import '../../../viewmodels/field_user/field_orders_viewmodel.dart';
import '../widgets/field_async_states.dart';

class FieldWeightReportView extends StatefulWidget {
  final OrderModel? order;
  final String? orderId;

  const FieldWeightReportView({
    super.key,
    this.order,
    this.orderId,
  }) : assert(order != null || orderId != null,
            'Provide either order or orderId');

  @override
  State<FieldWeightReportView> createState() => _FieldWeightReportViewState();
}

class _FieldWeightReportViewState extends State<FieldWeightReportView> {
  final _formKey = GlobalKey<FormState>();
  final _actualWeightController = TextEditingController();
  final _remarksController = TextEditingController();

  OrderModel? _order;
  bool _isLoading = true;
  String? _loadError;
  String? _submitError;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    if (_order != null) {
      _isLoading = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrder());
    }
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final order = await context
        .read<FieldOrdersViewModel>()
        .fetchOrder(widget.orderId!);
    if (!mounted) return;
    setState(() {
      _order = order;
      _loadError = order == null ? 'Order not found' : null;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _actualWeightController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final order = _order;
    if (order == null) return;

    setState(() => _submitError = null);

    final actualWeight = double.parse(_actualWeightController.text.trim());
    final success = await context.read<FieldOrdersViewModel>().submitWeightReport(
          orderId: order.orderId,
          companyId: order.companyId,
          actualWeight: actualWeight,
          remarks: _remarksController.text.trim().isEmpty
              ? null
              : _remarksController.text.trim(),
        );

    if (!mounted) return;

    if (success) {
      setState(() => _showSuccess = true);
      await Future<void>.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() {
        _submitError = context.read<FieldOrdersViewModel>().errorMessage ??
            'Could not submit weight report';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) {
      return Theme(
        data: FieldTheme.theme,
        child: Scaffold(
          backgroundColor: FieldColors.screenBackground,
          body: Center(
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
                  'Weight report submitted',
                  style: FieldTypography.headlineMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final vm = context.watch<FieldOrdersViewModel>();

    return Theme(
      data: FieldTheme.theme,
      child: Scaffold(
        backgroundColor: FieldColors.screenBackground,
        appBar: const FieldAppBar(title: 'Weight report'),
        body: _isLoading
            ? const FieldLoadingState(message: 'Loading order…')
            : _loadError != null
                ? FieldErrorState(
                    title: 'Could not load order',
                    message: _loadError!,
                    onRetry: _loadOrder,
                  )
                : Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        FieldSpacing.lg,
                        FieldSpacing.sm,
                        FieldSpacing.lg,
                        FieldSpacing.xxl,
                      ),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(FieldSpacing.md),
                          decoration: FieldTheme.cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _order!.materialName,
                                style: FieldTypography.titleMedium,
                              ),
                              const SizedBox(height: FieldSpacing.sm),
                              Text(
                                'Expected weight',
                                style: FieldTypography.labelSmall,
                              ),
                              const SizedBox(height: FieldSpacing.xs),
                              Text(
                                '${_order!.quantity.toStringAsFixed(_order!.quantity.truncateToDouble() == _order!.quantity ? 0 : 1)} ${_order!.unit}',
                                style: FieldTypography.headlineMedium.copyWith(
                                  color: FieldColors.primaryNavy,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: FieldSpacing.lg),
                        Text('Actual received weight', style: FieldTypography.labelSmall),
                        const SizedBox(height: FieldSpacing.xs),
                        TextFormField(
                          controller: _actualWeightController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}'),
                            ),
                          ],
                          decoration: InputDecoration(
                            hintText: 'Enter actual weight',
                            suffixText: _order!.unit,
                          ),
                          validator: (value) {
                            final weight = double.tryParse(value?.trim() ?? '');
                            if (weight == null || weight <= 0) {
                              return 'Enter a valid weight greater than 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: FieldSpacing.md),
                        Text('Remarks (optional)', style: FieldTypography.labelSmall),
                        const SizedBox(height: FieldSpacing.xs),
                        TextFormField(
                          controller: _remarksController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Note any variance or delivery issues',
                          ),
                        ),
                        if (_submitError != null) ...[
                          const SizedBox(height: FieldSpacing.md),
                          Text(
                            _submitError!,
                            style: FieldTypography.bodyMedium.copyWith(
                              color: FieldColors.statusDanger,
                            ),
                          ),
                        ],
                        const SizedBox(height: FieldSpacing.lg),
                        ElevatedButton(
                          onPressed: vm.isSubmitting ? null : _submit,
                          child: vm.isSubmitting
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: FieldColors.textPrimary,
                                  ),
                                )
                              : const Text('Submit report'),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
