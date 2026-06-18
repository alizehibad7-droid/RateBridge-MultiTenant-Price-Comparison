import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../models/order_model.dart';
import '../../widgets/rating_stars_widget.dart';
import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';

class FieldSupplierProfileView extends StatelessWidget {
  final String supplierId;
  final String supplierName;

  const FieldSupplierProfileView({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Supplier Profile", 
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Performance Scorecard", theme),
                  const SizedBox(height: 20),
                  _buildRatingBreakdown(theme),
                  const SizedBox(height: 48),
                  _buildSectionTitle("Material Catalog", theme),
                  const SizedBox(height: 20),
                  _buildMaterialsPlaceholder(theme),
                  const SizedBox(height: 48),
                  _buildSectionTitle("Field Feedback", theme),
                  const SizedBox(height: 20),
                  _buildReviewsList(theme),
                  const SizedBox(height: 140), 
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse('tel:+923001234567')),
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text("CALL"),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navigate to chat. For simplicity, we assume there's an active context or general chat
                  context.push(RouteNames.fieldChat);
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text("SEND MESSAGE"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title.toUpperCase(),
      style: theme.textTheme.labelLarge?.copyWith(
        color: AppColors.textSecondary,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 48),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      width: double.infinity,
      child: Column(
        children: [
          const CircleAvatar(
            radius: 40,
            backgroundColor: AppColors.surface,
            child: Icon(Icons.business_rounded, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                supplierName, 
                style: theme.textTheme.displaySmall?.copyWith(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.verified_rounded, color: AppColors.primary, size: 22),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Industrial Estate • Verified Partner", 
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBreakdown(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _ratingRow("Material Quality", 4.9),
          const Divider(height: 32),
          _ratingRow("Delivery Reliability", 4.7),
          const Divider(height: 32),
          _ratingRow("Packaging Standard", 4.5),
        ],
      ),
    );
  }

  Widget _ratingRow(String label, double rating) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        const Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
        const SizedBox(width: 4),
        Text(rating.toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildMaterialsPlaceholder(ThemeData theme) {
    return const Text("Viewing supplier's global catalog optimized for your firm...", style: TextStyle(color: AppColors.textSecondary, fontSize: 13));
  }

  Widget _buildReviewsList(ThemeData theme) {
    return const Text("Recent feedback from your site engineers will appear here.", style: TextStyle(color: AppColors.textSecondary, fontSize: 13));
  }
}
