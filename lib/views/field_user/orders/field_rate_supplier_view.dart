import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../models/order_model.dart';
import '../../../models/rating_model.dart';
import '../../../theme/field_theme.dart';
import '../../../viewmodels/field_user/field_rating_viewmodel.dart';
import '../../../viewmodels/field_user/field_session_viewmodel.dart';
import '../orders/field_order_status.dart';
import '../widgets/field_async_states.dart';

class FieldRateSupplierView extends StatefulWidget {
  final OrderModel order;

  const FieldRateSupplierView({super.key, required this.order});

  @override
  State<FieldRateSupplierView> createState() => _FieldRateSupplierViewState();
}

class _FieldRateSupplierViewState extends State<FieldRateSupplierView> {
  final _commentController = TextEditingController();

  int _overallRating = 0;
  int _qualityRating = 0;
  int _deliveryRating = 0;

  bool _isCheckingExisting = true;
  bool _alreadyRated = false;
  String? _loadError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkExistingRating());
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingRating() async {
    if (!FieldOrderStatus.canRate(widget.order.status)) {
      setState(() {
        _isCheckingExisting = false;
        _loadError =
            'You can rate the supplier after delivery has been confirmed.';
      });
      return;
    }

    final uid = context.read<FieldSessionViewModel>().user?.uid;
    if (uid == null) {
      setState(() {
        _isCheckingExisting = false;
        _loadError = 'You must be signed in to rate this order.';
      });
      return;
    }

    final alreadyRated = await context
        .read<FieldRatingViewModel>()
        .hasUserRatedOrder(widget.order.orderId, uid);

    if (!mounted) return;

    setState(() {
      _isCheckingExisting = false;
      _alreadyRated = alreadyRated;
      if (context.read<FieldRatingViewModel>().errorMessage != null) {
        _loadError = context.read<FieldRatingViewModel>().errorMessage;
      }
    });
  }

  bool get _showDimensionHint =>
      _overallRating > 0 && (_qualityRating == 0 || _deliveryRating == 0);

  Map<String, double> _buildDimensions() {
    final dimensions = <String, double>{};
    if (_qualityRating > 0) {
      dimensions['Quality'] = _qualityRating.toDouble();
    }
    if (_deliveryRating > 0) {
      dimensions['Timeliness'] = _deliveryRating.toDouble();
    }
    return dimensions;
  }

  Future<void> _submit() async {
    if (_overallRating < 1) {
      setState(() => _submitError = 'Please rate your overall experience.');
      return;
    }

    setState(() {
      _submitError = null;
      context.read<FieldRatingViewModel>().clearError();
    });

    final session = context.read<FieldSessionViewModel>();
    final uid = session.user?.uid;
    final userName = session.user?.name ?? 'Field User';
    if (uid == null) return;

    final rating = RatingModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      orderId: widget.order.orderId,
      supplierUid: widget.order.supplierId,
      userId: uid,
      userName: userName,
      materialId: widget.order.materialId,
      materialName: widget.order.materialName,
      rating: _overallRating.toDouble(),
      comment: _commentController.text.trim(),
      dimensions: _buildDimensions(),
      createdAt: DateTime.now(),
    );

    final result = await context.read<FieldRatingViewModel>().submitRating(
          orderId: widget.order.orderId,
          companyId: widget.order.companyId,
          rating: rating,
        );

    if (!mounted) return;

    if (result == FieldRatingSubmitResult.success) {
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rating submitted!')),
      );
    } else if (result == FieldRatingSubmitResult.alreadyRated) {
      await _showAlreadyRatedDialog();
    } else {
      final message = context.read<FieldRatingViewModel>().errorMessage ??
          'Could not submit rating. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      setState(() => _submitError = message);
    }
  }

  Future<void> _showAlreadyRatedDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Already rated this order'),
        content: const Text('Each order can only be rated once.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) setState(() => _alreadyRated = true);
  }

  void _returnToOrdersList() {
    context.pop();
    if (context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FieldRatingViewModel>();

    return Theme(
      data: FieldTheme.theme,
      child: Scaffold(
        backgroundColor: FieldColors.screenBackground,
        appBar: const FieldAppBar(title: 'Rate delivery'),
        body: _isCheckingExisting || vm.isCheckingExisting
                ? const FieldLoadingState(message: 'Loading rating…')
                : _loadError != null
                    ? FieldErrorState(
                        message: _loadError!,
                        onRetry: _checkExistingRating,
                      )
                    : _alreadyRated
                        ? _AlreadyRatedBody(onBack: _returnToOrdersList)
                        : _RatingForm(
                            order: widget.order,
                            overallRating: _overallRating,
                            qualityRating: _qualityRating,
                            deliveryRating: _deliveryRating,
                            commentController: _commentController,
                            showDimensionHint: _showDimensionHint,
                            submitError: _submitError,
                            isSubmitting: vm.isLoading,
                            onOverallChanged: (value) =>
                                setState(() => _overallRating = value),
                            onQualityChanged: (value) =>
                                setState(() => _qualityRating = value),
                            onDeliveryChanged: (value) =>
                                setState(() => _deliveryRating = value),
                            onSubmit: _submit,
                          ),
      ),
    );
  }
}

class _RatingForm extends StatelessWidget {
  final OrderModel order;
  final int overallRating;
  final int qualityRating;
  final int deliveryRating;
  final TextEditingController commentController;
  final bool showDimensionHint;
  final String? submitError;
  final bool isSubmitting;
  final ValueChanged<int> onOverallChanged;
  final ValueChanged<int> onQualityChanged;
  final ValueChanged<int> onDeliveryChanged;
  final VoidCallback onSubmit;

  const _RatingForm({
    required this.order,
    required this.overallRating,
    required this.qualityRating,
    required this.deliveryRating,
    required this.commentController,
    required this.showDimensionHint,
    required this.submitError,
    required this.isSubmitting,
    required this.onOverallChanged,
    required this.onQualityChanged,
    required this.onDeliveryChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
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
              Text(order.supplierName, style: FieldTypography.titleMedium),
              const SizedBox(height: FieldSpacing.xs),
              Text(order.materialName, style: FieldTypography.bodyMedium),
              const SizedBox(height: FieldSpacing.sm),
              Text(
                'Order #${order.orderId}',
                style: FieldTypography.labelSmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: FieldSpacing.lg),
        _StarRatingRow(
          label: 'Overall experience',
          required: true,
          value: overallRating,
          onChanged: onOverallChanged,
        ),
        const SizedBox(height: FieldSpacing.md),
        _StarRatingRow(
          label: 'Material quality',
          value: qualityRating,
          onChanged: onQualityChanged,
        ),
        const SizedBox(height: FieldSpacing.md),
        _StarRatingRow(
          label: 'Delivery reliability',
          value: deliveryRating,
          onChanged: onDeliveryChanged,
        ),
        if (showDimensionHint) ...[
          const SizedBox(height: FieldSpacing.sm),
          Text(
            'Quality and delivery ratings are optional, but help suppliers improve.',
            style: FieldTypography.bodyMedium.copyWith(
              color: FieldColors.textMuted,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: FieldSpacing.lg),
        Text('Comment (optional)', style: FieldTypography.labelSmall),
        const SizedBox(height: FieldSpacing.xs),
        TextField(
          controller: commentController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Anything else worth sharing about this order?',
            alignLabelWithHint: true,
          ),
        ),
        if (submitError != null) ...[
          const SizedBox(height: FieldSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(FieldSpacing.md),
            decoration: BoxDecoration(
              color: FieldColors.statusDanger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(FieldRadius.card),
              border: Border.all(
                color: FieldColors.statusDanger.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: FieldColors.statusDanger,
                    ),
                    const SizedBox(width: FieldSpacing.sm),
                    Expanded(
                      child: Text(
                        submitError!,
                        style: FieldTypography.bodyMedium.copyWith(
                          color: FieldColors.statusDanger,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FieldSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isSubmitting ? null : onSubmit,
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: FieldSpacing.lg),
        ElevatedButton(
          onPressed: (isSubmitting || overallRating < 1) ? null : onSubmit,
          child: isSubmitting
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: FieldColors.textPrimary,
                  ),
                )
              : const Text('Submit rating'),
        ),
      ],
    );
  }
}

class _StarRatingRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final bool required;

  const _StarRatingRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: FieldTypography.labelSmall),
            if (required) ...[
              const SizedBox(width: FieldSpacing.xs),
              Text(
                '*',
                style: FieldTypography.labelSmall.copyWith(
                  color: FieldColors.statusDanger,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: FieldSpacing.xs),
        Row(
          children: List.generate(5, (index) {
            final star = index + 1;
            return IconButton(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              onPressed: () => onChanged(star),
              icon: Icon(
                star <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 32,
                color: FieldColors.accentAmber,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _AlreadyRatedBody extends StatelessWidget {
  final VoidCallback onBack;

  const _AlreadyRatedBody({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FieldSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rounded,
              size: 48,
              color: FieldColors.textMuted.withValues(alpha: 0.7),
            ),
            const SizedBox(height: FieldSpacing.md),
            Text(
              "You've already rated this order",
              style: FieldTypography.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: FieldSpacing.sm),
            Text(
              'Each order can only be rated once.',
              textAlign: TextAlign.center,
              style: FieldTypography.bodyMedium,
            ),
            const SizedBox(height: FieldSpacing.lg),
            OutlinedButton(
              onPressed: onBack,
              child: const Text('Back to orders'),
            ),
          ],
        ),
      ),
    );
  }
}
