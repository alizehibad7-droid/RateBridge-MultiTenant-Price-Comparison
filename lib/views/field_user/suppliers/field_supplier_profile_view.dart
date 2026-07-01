import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/route_names.dart';
import '../../../models/supplier_model.dart';
import '../../../theme/field_theme.dart';
import '../../../viewmodels/field_user/field_session_viewmodel.dart';
import '../../../viewmodels/field_user/field_supplier_profile_viewmodel.dart';
import '../../../widgets/rating_stars_widget.dart';
import '../chat/field_chat_thread_args.dart';
import '../widgets/field_async_states.dart';

class FieldSupplierProfileView extends StatefulWidget {
  final String supplierUid;

  const FieldSupplierProfileView({super.key, required this.supplierUid});

  @override
  State<FieldSupplierProfileView> createState() =>
      _FieldSupplierProfileViewState();
}

class _FieldSupplierProfileViewState extends State<FieldSupplierProfileView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final companyId = context.read<FieldSessionViewModel>().companyId;
    if (companyId == null) return;
    await context
        .read<FieldSupplierProfileViewModel>()
        .load(companyId, widget.supplierUid);
  }

  Future<void> _callSupplier() async {
    final phone = context.read<FieldSupplierProfileViewModel>().supplier?.contact;
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supplier phone number not available')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.trim());
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open phone dialer')),
      );
    }
  }

  void _messageSupplier() {
    final vm = context.read<FieldSupplierProfileViewModel>();
    final supplier = vm.supplier;
    if (supplier == null) return;
    context.push(
      RouteNames.fieldChatThread.replaceFirst(':orderId', supplier.id),
      extra: FieldChatThreadArgs(
        supplierUid: supplier.id,
        supplierName: supplier.name,
      ),
    );
  }

  String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FieldSupplierProfileViewModel>();
    final supplier = vm.supplier;

    return Theme(
      data: FieldTheme.theme,
      child: Scaffold(
        backgroundColor: FieldColors.screenBackground,
        appBar: FieldAppBar(
          title: supplier?.name ?? 'Supplier',
        ),
        body: vm.isLoading && supplier == null
            ? const FieldLoadingState(message: 'Loading supplier…')
            : vm.errorMessage != null && supplier == null
                ? FieldErrorState(
                    title: 'Could not load supplier',
                    message: vm.errorMessage!,
                    onRetry: _load,
                  )
                : Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(
                            FieldSpacing.lg,
                            FieldSpacing.sm,
                            FieldSpacing.lg,
                            FieldSpacing.md,
                          ),
                          children: [
                            _SupplierHeader(supplier: supplier!),
                            const SizedBox(height: FieldSpacing.lg),
                            _RatingBreakdownCard(
                              averageRating: vm.averageRating,
                              qualityAverage: vm.qualityAverage,
                              deliveryAverage: vm.deliveryAverage,
                              reviewCount: vm.ratingCount,
                            ),
                            const SizedBox(height: FieldSpacing.lg),
                            Text('Materials', style: FieldTypography.titleMedium),
                            const SizedBox(height: FieldSpacing.sm),
                            if (vm.materials.isEmpty)
                              Text(
                                'No materials listed for your company yet.',
                                style: FieldTypography.bodyMedium,
                              )
                            else
                              ...vm.materials.map(
                                (material) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: FieldSpacing.sm,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(FieldSpacing.md),
                                    decoration: FieldTheme.cardDecoration(),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                material.name,
                                                style: FieldTypography.titleMedium,
                                              ),
                                              const SizedBox(height: FieldSpacing.xs),
                                              Text(
                                                material.category,
                                                style: FieldTypography.bodyMedium,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          'Rs ${material.pricePerUnit.toStringAsFixed(0)}/${material.unit}',
                                          style: FieldTypography.bodyLarge.copyWith(
                                            color: FieldColors.primaryNavy,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: FieldSpacing.lg),
                            Text('Recent reviews', style: FieldTypography.titleMedium),
                            const SizedBox(height: FieldSpacing.sm),
                            if (vm.recentRatings.isEmpty)
                              Text(
                                'No reviews yet for this supplier.',
                                style: FieldTypography.bodyMedium,
                              )
                            else
                              ...vm.recentRatings.map(
                                (rating) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: FieldSpacing.sm,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(FieldSpacing.md),
                                    decoration: FieldTheme.cardDecoration(),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            RatingStarsWidget(
                                              rating: rating.rating,
                                              size: 14,
                                            ),
                                            const Spacer(),
                                            Text(
                                              _relativeDate(rating.createdAt),
                                              style: FieldTypography.labelSmall
                                                  .copyWith(fontSize: 10),
                                            ),
                                          ],
                                        ),
                                        if (rating.comment.trim().isNotEmpty) ...[
                                          const SizedBox(height: FieldSpacing.sm),
                                          Text(
                                            rating.comment,
                                            style: FieldTypography.bodyMedium,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      _BottomActionBar(
                        onCall: _callSupplier,
                        onMessage: _messageSupplier,
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _SupplierHeader extends StatelessWidget {
  final SupplierModel supplier;

  const _SupplierHeader({required this.supplier});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FieldSpacing.md),
      decoration: FieldTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  supplier.name,
                  style: FieldTypography.headlineMedium.copyWith(fontSize: 18),
                ),
              ),
              if (supplier.isVerified)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FieldSpacing.sm,
                    vertical: FieldSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: FieldColors.statusSuccess.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(FieldRadius.chip),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified,
                        size: 14,
                        color: FieldColors.statusSuccess,
                      ),
                      const SizedBox(width: FieldSpacing.xs),
                      Text(
                        'Verified',
                        style: FieldTypography.labelSmall.copyWith(
                          color: FieldColors.statusSuccess,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (supplier.city.isNotEmpty) ...[
            const SizedBox(height: FieldSpacing.sm),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: FieldColors.textMuted,
                ),
                const SizedBox(width: FieldSpacing.xs),
                Text(supplier.city, style: FieldTypography.bodyMedium),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingBreakdownCard extends StatelessWidget {
  final double averageRating;
  final double qualityAverage;
  final double deliveryAverage;
  final int reviewCount;

  const _RatingBreakdownCard({
    required this.averageRating,
    required this.qualityAverage,
    required this.deliveryAverage,
    required this.reviewCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(FieldSpacing.md),
      decoration: FieldTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                averageRating > 0 ? averageRating.toStringAsFixed(1) : '—',
                style: FieldTypography.displayLarge.copyWith(fontSize: 32),
              ),
              const SizedBox(width: FieldSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RatingStarsWidget(rating: averageRating, size: 18),
                  const SizedBox(height: FieldSpacing.xs),
                  Text(
                    reviewCount > 0
                        ? 'Based on supplier ratings'
                        : 'No ratings yet',
                    style: FieldTypography.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
          if (qualityAverage > 0 || deliveryAverage > 0) ...[
            const SizedBox(height: FieldSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: FieldSpacing.md),
            if (qualityAverage > 0)
              _DimensionRow(label: 'Material quality', value: qualityAverage),
            if (deliveryAverage > 0) ...[
              const SizedBox(height: FieldSpacing.sm),
              _DimensionRow(label: 'Delivery reliability', value: deliveryAverage),
            ],
          ],
        ],
      ),
    );
  }
}

class _DimensionRow extends StatelessWidget {
  final String label;
  final double value;

  const _DimensionRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: FieldTypography.bodyMedium)),
        RatingStarsWidget(rating: value, size: 14),
        const SizedBox(width: FieldSpacing.sm),
        Text(
          value.toStringAsFixed(1),
          style: FieldTypography.labelSmall,
        ),
      ],
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final VoidCallback onCall;
  final VoidCallback onMessage;

  const _BottomActionBar({
    required this.onCall,
    required this.onMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        FieldSpacing.lg,
        FieldSpacing.md,
        FieldSpacing.lg,
        FieldSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: FieldColors.surfaceWhite,
        border: Border(top: BorderSide(color: FieldColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onCall,
              icon: const Icon(Icons.phone_outlined, size: 18),
              label: const Text('Call'),
            ),
          ),
          const SizedBox(width: FieldSpacing.sm),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onMessage,
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Message'),
            ),
          ),
        ],
      ),
    );
  }
}
