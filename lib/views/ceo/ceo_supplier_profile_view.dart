import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/route_names.dart';
import '../../models/material_model.dart';
import '../../models/rating_model.dart';
import '../../models/supplier_model.dart';
import '../../theme/ceo_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/ceo_supplier_profile_viewmodel.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../widgets/app_network_image.dart';
import '../../widgets/admin/admin_widgets.dart';
import '../../widgets/rating_stars_widget.dart';

/// Shared CEO Supplier Details screen (Partners + Marketplace).
class CeoSupplierProfileView extends StatefulWidget {
  final String supplierUid;

  const CeoSupplierProfileView({super.key, required this.supplierUid});

  @override
  State<CeoSupplierProfileView> createState() => _CeoSupplierProfileViewState();
}

class _CeoSupplierProfileViewState extends State<CeoSupplierProfileView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(covariant CeoSupplierProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.supplierUid != widget.supplierUid) {
      _load();
    }
  }

  Future<void> _load() async {
    final companyId =
        context.read<AuthViewModel>().user?.companyId ??
            context.read<CeoViewModel>().company?.id;
    await context.read<CeoSupplierProfileViewModel>().load(
          supplierId: widget.supplierUid,
          companyId: companyId,
        );
  }

  Future<void> _call(String? phone) async {
    final trimmed = phone?.trim() ?? '';
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: trimmed);
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open phone dialer')),
      );
    }
  }

  Future<void> _email(String? email) async {
    final trimmed = email?.trim() ?? '';
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email not available')),
      );
      return;
    }
    final uri = Uri(scheme: 'mailto', path: trimmed);
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email client')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CeoSupplierProfileViewModel>();
    final ceoVm = context.watch<CeoViewModel>();
    final supplier = vm.supplier;
    final partnershipStatus = ceoVm.linkStatusFor(widget.supplierUid);

    return Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: CeoAppBar(
        title: supplier?.name ?? 'Supplier Profile',
        automaticallyImplyLeading: true,
        showNotificationIcon: false,
      ),
      body: vm.isLoading && supplier == null
          ? const Center(child: CircularProgressIndicator())
          : vm.errorMessage != null && supplier == null
              ? _ErrorBody(
                  message: vm.errorMessage!,
                  onRetry: _load,
                )
              : supplier == null
                  ? const _ErrorBody(
                      message: 'Supplier not found.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: CeoColors.navy,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        children: [
                          _OverviewCard(
                            supplier: supplier,
                            partnershipStatus: partnershipStatus,
                            onCall: () => _call(supplier.contact),
                            onEmail: () => _email(supplier.email),
                          ),
                          if (_hasBusinessInfo(supplier)) ...[
                            const SizedBox(height: 16),
                            _SectionCard(
                              title: 'Business Information',
                              icon: Icons.storefront_outlined,
                              child: _BusinessInfo(supplier: supplier),
                            ),
                          ],
                          if (_hasVerification(supplier)) ...[
                            const SizedBox(height: 16),
                            _SectionCard(
                              title: 'Verification',
                              icon: Icons.verified_outlined,
                              child: _VerificationInfo(supplier: supplier),
                            ),
                          ],
                          if (_hasDelivery(supplier)) ...[
                            const SizedBox(height: 16),
                            _SectionCard(
                              title: 'Delivery',
                              icon: Icons.local_shipping_outlined,
                              child: _DeliveryInfo(supplier: supplier),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Partnership',
                            icon: Icons.handshake_outlined,
                            child: _PartnershipInfo(
                              status: partnershipStatus,
                              rejectionReason:
                                  ceoVm.linkRejectionReasonFor(widget.supplierUid),
                              fulfilledOrders: vm.companyFulfilledOrders,
                              onTimeRate: vm.companyOnTimeRate,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Ratings & Reviews',
                            icon: Icons.star_outline_rounded,
                            child: _RatingsSection(
                              average: vm.averageRating,
                              count: vm.ratingCount,
                              quality: vm.qualityAverage,
                              delivery: vm.deliveryAverage,
                              reviews: vm.recentRatings,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Materials & Products',
                            icon: Icons.inventory_2_outlined,
                            child: vm.materials.isEmpty
                                ? Text(
                                    'No listed materials available for this supplier yet.',
                                    style: CeoTheme.mutedStyle(size: 13),
                                  )
                                : Column(
                                    children: [
                                      for (var i = 0;
                                          i < vm.materials.length;
                                          i++) ...[
                                        if (i > 0) const Divider(height: 20),
                                        _MaterialTile(material: vm.materials[i]),
                                      ],
                                    ],
                                  ),
                          ),
                          if (_hasDocuments(supplier)) ...[
                            const SizedBox(height: 16),
                            _SectionCard(
                              title: 'Documents & Photos',
                              icon: Icons.folder_open_outlined,
                              child: _DocumentsSection(supplier: supplier),
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }

  bool _hasBusinessInfo(SupplierModel s) =>
      (s.businessType?.trim().isNotEmpty ?? false) ||
      (s.ownerFullName?.trim().isNotEmpty ?? false) ||
      (s.businessRegistrationNumber?.trim().isNotEmpty ?? false) ||
      (s.yearsInBusiness != null && s.yearsInBusiness! > 0) ||
      (s.businessAddress?.trim().isNotEmpty ?? false) ||
      s.materialType.trim().isNotEmpty ||
      s.categories.isNotEmpty ||
      s.declaredCategories.isNotEmpty;

  bool _hasVerification(SupplierModel s) =>
      s.isVerified ||
      s.status.trim().isNotEmpty ||
      (s.businessLicenseUrl?.trim().isNotEmpty ?? false) ||
      (s.certificationUrl?.trim().isNotEmpty ?? false);

  bool _hasDelivery(SupplierModel s) =>
      s.deliveryCoverageAreas.isNotEmpty || s.leadTimeDays > 0;

  bool _hasDocuments(SupplierModel s) =>
      (s.shopPhotoUrl?.trim().isNotEmpty ?? false) ||
      (s.businessLicenseUrl?.trim().isNotEmpty ?? false) ||
      (s.certificationUrl?.trim().isNotEmpty ?? false);
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorBody({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: CeoColors.textGrey),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: CeoTheme.mutedStyle(size: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: CeoColors.navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: CeoTheme.titleStyle(size: 15).copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final SupplierModel supplier;
  final String partnershipStatus;
  final VoidCallback onCall;
  final VoidCallback onEmail;

  const _OverviewCard({
    required this.supplier,
    required this.partnershipStatus,
    required this.onCall,
    required this.onEmail,
  });

  @override
  Widget build(BuildContext context) {
    final photo = supplier.shopPhotoUrl?.trim() ?? '';
    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 64,
                  height: 64,
                  color: CeoColors.navy.withValues(alpha: 0.08),
                  child: photo.isNotEmpty
                      ? AppNetworkImage(
                          url: photo,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          debugLabel: 'ceo-supplier:${supplier.id}',
                          fallback: Center(
                            child: Text(
                              supplier.name.isNotEmpty
                                  ? supplier.name[0].toUpperCase()
                                  : 'S',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 24,
                                color: CeoColors.navy,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            supplier.name.isNotEmpty
                                ? supplier.name[0].toUpperCase()
                                : 'S',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                              color: CeoColors.navy,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            supplier.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: CeoColors.navy,
                            ),
                          ),
                        ),
                        if (supplier.isVerified)
                          const Icon(
                            Icons.verified_rounded,
                            color: CeoColors.green,
                            size: 20,
                          ),
                      ],
                    ),
                    if (supplier.city.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: CeoColors.textGrey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              supplier.city,
                              style: CeoTheme.mutedStyle(size: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Chip(
                          label: partnershipStatus == 'Already Partners'
                              ? 'Partner'
                              : partnershipStatus,
                          color: partnershipStatus == 'Already Partners'
                              ? CeoColors.green
                              : partnershipStatus == 'Request Pending'
                                  ? CeoColors.amber
                                  : CeoColors.navy,
                        ),
                        if (supplier.status.trim().isNotEmpty)
                          _Chip(
                            label: supplier.status,
                            color: CeoColors.navy,
                          ),
                        if (supplier.commissionRestricted)
                          const _Chip(
                            label: 'Temporarily unavailable',
                            color: CeoColors.red,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (supplier.contact.trim().isNotEmpty ||
              supplier.email.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (supplier.contact.trim().isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.call_outlined, size: 16),
                    label: Text(supplier.contact),
                    style: CeoTheme.secondaryButtonStyle(height: 40),
                  ),
                if (supplier.email.trim().isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: onEmail,
                    icon: const Icon(Icons.email_outlined, size: 16),
                    label: const Text('Email'),
                    style: CeoTheme.secondaryButtonStyle(height: 40),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(label, style: CeoTheme.mutedStyle(size: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CeoColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessInfo extends StatelessWidget {
  final SupplierModel supplier;

  const _BusinessInfo({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final cats = <String>{
      ...supplier.categories,
      ...supplier.declaredCategories,
      if (supplier.materialType.trim().isNotEmpty) supplier.materialType,
    }.where((c) => c.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (supplier.businessType?.trim().isNotEmpty ?? false)
          _InfoRow(label: 'Business type', value: supplier.businessType!.trim()),
        if (supplier.ownerFullName?.trim().isNotEmpty ?? false)
          _InfoRow(label: 'Owner', value: supplier.ownerFullName!.trim()),
        if (supplier.businessRegistrationNumber?.trim().isNotEmpty ?? false)
          _InfoRow(
            label: 'Registration',
            value: supplier.businessRegistrationNumber!.trim(),
          ),
        if (supplier.yearsInBusiness != null && supplier.yearsInBusiness! > 0)
          _InfoRow(
            label: 'Years active',
            value: '${supplier.yearsInBusiness}',
          ),
        if (supplier.businessAddress?.trim().isNotEmpty ?? false)
          _InfoRow(
            label: 'Address',
            value: supplier.businessAddress!.trim(),
          ),
        if (supplier.activeContracts > 0)
          _InfoRow(
            label: 'Active contracts',
            value: '${supplier.activeContracts}',
          ),
        if (cats.isNotEmpty) ...[
          Text('Categories', style: CeoTheme.mutedStyle(size: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cats
                .map(
                  (c) => _Chip(label: c, color: CeoColors.navy),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _VerificationInfo extends StatelessWidget {
  final SupplierModel supplier;

  const _VerificationInfo({required this.supplier});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoRow(
          label: 'Verified',
          value: supplier.isVerified ? 'Yes' : 'No',
        ),
        if (supplier.status.trim().isNotEmpty)
          _InfoRow(label: 'Account status', value: supplier.status),
        if (supplier.businessLicenseUrl?.trim().isNotEmpty ?? false)
          _InfoRow(label: 'Business license', value: 'On file'),
        if (supplier.certificationUrl?.trim().isNotEmpty ?? false)
          _InfoRow(label: 'Certification', value: 'On file'),
      ],
    );
  }
}

class _DeliveryInfo extends StatelessWidget {
  final SupplierModel supplier;

  const _DeliveryInfo({required this.supplier});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (supplier.leadTimeDays > 0)
          _InfoRow(
            label: 'Lead time',
            value: '${supplier.leadTimeDays} day(s)',
          ),
        if (supplier.deliveryCoverageAreas.isNotEmpty) ...[
          Text('Coverage areas', style: CeoTheme.mutedStyle(size: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: supplier.deliveryCoverageAreas
                .map((a) => _Chip(label: a, color: CeoColors.navy))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _PartnershipInfo extends StatelessWidget {
  final String status;
  final String? rejectionReason;
  final int fulfilledOrders;
  final double onTimeRate;

  const _PartnershipInfo({
    required this.status,
    this.rejectionReason,
    required this.fulfilledOrders,
    required this.onTimeRate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(label: 'Status', value: status),
        if (rejectionReason != null && rejectionReason!.trim().isNotEmpty)
          _InfoRow(label: 'Rejection note', value: rejectionReason!.trim()),
        if (fulfilledOrders > 0) ...[
          _InfoRow(
            label: 'Orders with you',
            value: '$fulfilledOrders fulfilled',
          ),
          _InfoRow(
            label: 'On-time rate',
            value: '${onTimeRate.toStringAsFixed(0)}%',
          ),
        ],
      ],
    );
  }
}

class _RatingsSection extends StatelessWidget {
  final double average;
  final int count;
  final double quality;
  final double delivery;
  final List<RatingModel> reviews;

  const _RatingsSection({
    required this.average,
    required this.count,
    required this.quality,
    required this.delivery,
    required this.reviews,
  });

  @override
  Widget build(BuildContext context) {
    if (average <= 0 && count == 0 && reviews.isEmpty) {
      return Text(
        'No ratings yet for this supplier.',
        style: CeoTheme.mutedStyle(size: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              average > 0 ? average.toStringAsFixed(1) : '—',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: CeoColors.navy,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RatingStarsWidget(rating: average, size: 18),
                  const SizedBox(height: 4),
                  Text(
                    count > 0
                        ? '$count review${count == 1 ? '' : 's'}'
                        : 'Based on supplier rating',
                    style: CeoTheme.mutedStyle(size: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (quality > 0 || delivery > 0) ...[
          const SizedBox(height: 12),
          if (quality > 0)
            _InfoRow(label: 'Quality avg', value: quality.toStringAsFixed(1)),
          if (delivery > 0)
            _InfoRow(label: 'Delivery avg', value: delivery.toStringAsFixed(1)),
        ],
        if (reviews.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'Recent reviews',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: CeoColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          for (final r in reviews) ...[
            _ReviewTile(review: r),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final RatingModel review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CeoColors.screenBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CeoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.userName.trim().isNotEmpty
                      ? review.userName
                      : 'Field user',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: CeoColors.navy,
                  ),
                ),
              ),
              RatingStarsWidget(rating: review.rating, size: 14),
            ],
          ),
          if (review.materialName.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(review.materialName, style: CeoTheme.mutedStyle(size: 12)),
          ],
          if (review.comment.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.comment,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: CeoColors.navy,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            DateFormat('MMM d, yyyy').format(review.createdAt),
            style: CeoTheme.mutedStyle(size: 11),
          ),
        ],
      ),
    );
  }
}

class _MaterialTile extends StatelessWidget {
  final MaterialModel material;

  const _MaterialTile({required this.material});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          material.name,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: CeoColors.navy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          [
            if (material.category.isNotEmpty) material.category,
            if ((material.brand ?? '').trim().isNotEmpty) material.brand,
            if (material.qualityGrade.isNotEmpty) material.qualityGrade,
          ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' · '),
          style: CeoTheme.mutedStyle(size: 12),
        ),
        const SizedBox(height: 6),
        Text(
          '${CurrencyFormatter.formatPKR(material.pricePerUnit)} / ${material.unit}',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: CeoColors.navy,
          ),
        ),
        if (material.specifications.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(material.specifications, style: CeoTheme.mutedStyle(size: 12)),
        ],
        if ((material.description ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(material.description!.trim(), style: CeoTheme.mutedStyle(size: 12)),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (material.minOrderQuantity != null &&
                material.minOrderQuantity! > 0)
              _Chip(
                label: 'MOQ ${material.minOrderQuantity!.toStringAsFixed(
                  material.minOrderQuantity! % 1 == 0 ? 0 : 1,
                )} ${material.unit}',
                color: CeoColors.navy,
              ),
            if ((material.stockStatus ?? '').trim().isNotEmpty)
              _Chip(label: material.stockStatus!.trim(), color: CeoColors.green),
            if (material.bulkDiscountAvailable == true)
              _Chip(
                label: (material.bulkDiscountDetails ?? '').trim().isNotEmpty
                    ? material.bulkDiscountDetails!.trim()
                    : 'Bulk discount',
                color: CeoColors.amber,
              ),
            if ((material.deliveryTime ?? '').trim().isNotEmpty)
              _Chip(
                label: material.deliveryTime!.trim(),
                color: CeoColors.navy,
              ),
            if ((material.deliveryCoverageArea ?? '').trim().isNotEmpty)
              _Chip(
                label: material.deliveryCoverageArea!.trim(),
                color: CeoColors.navy,
              ),
            if ((material.deliveryCharges ?? '').trim().isNotEmpty)
              _Chip(
                label: 'Delivery: ${material.deliveryCharges!.trim()}',
                color: CeoColors.navy,
              ),
            if (material.isCertified)
              const _Chip(label: 'Certified', color: CeoColors.green),
            if (material.originCity.trim().isNotEmpty)
              _Chip(label: material.originCity, color: CeoColors.navy),
          ],
        ),
      ],
    );
  }
}

class _DocumentsSection extends StatelessWidget {
  final SupplierModel supplier;

  const _DocumentsSection({required this.supplier});

  @override
  Widget build(BuildContext context) {
    final items = <({String label, String url})>[
      if ((supplier.shopPhotoUrl ?? '').trim().isNotEmpty)
        (label: 'Shop photo', url: supplier.shopPhotoUrl!.trim()),
      if ((supplier.businessLicenseUrl ?? '').trim().isNotEmpty)
        (label: 'Business license', url: supplier.businessLicenseUrl!.trim()),
      if ((supplier.certificationUrl ?? '').trim().isNotEmpty)
        (label: 'Certification', url: supplier.certificationUrl!.trim()),
    ];

    return Column(
      children: [
        for (final item in items) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.link_rounded, color: CeoColors.navy),
            title: Text(
              item.label,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: CeoColors.navy,
              ),
            ),
            trailing: const Icon(Icons.open_in_new_rounded, size: 16),
            onTap: () async {
              final uri = Uri.tryParse(item.url);
              if (uri == null) return;
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ],
    );
  }
}

/// Shared navigation helper for Partners + Marketplace.
void openCeoSupplierProfile(BuildContext context, String supplierId) {
  final id = supplierId.trim();
  if (id.isEmpty) return;
  context.push(
    RouteNames.ceoSupplierProfile.replaceFirst(':supplierUid', id),
  );
}
