// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme/supplier_theme.dart';
import '../../models/rating_model.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../widgets/supplier/supplier_async_states.dart';

class SupplierRatingsView extends StatefulWidget {
  const SupplierRatingsView({super.key});

  @override
  State<SupplierRatingsView> createState() => _SupplierRatingsViewState();
}

class _SupplierRatingsViewState extends State<SupplierRatingsView> {
  String _selectedMaterial = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<SupplierViewModel>();
      if (vm.supplierUid != null && vm.selectedCompanyId != null) {
        vm.loadRatings(vm.supplierUid!, vm.selectedCompanyId!);
      }
    });
  }

  double? _averageScore(Iterable<double> scores) {
    final values = scores.where((s) => s > 0).toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double? _avgOverall(List<RatingModel> ratings) =>
      _averageScore(ratings.map((r) => r.rating));

  double? _avgQuality(List<RatingModel> ratings) =>
      _averageScore(ratings.map((r) => r.qualityScore));

  double? _avgPackaging(List<RatingModel> ratings) =>
      _averageScore(ratings.map((r) => r.packagingScore));

  double? _avgQuantity(List<RatingModel> ratings) =>
      _averageScore(ratings.map((r) => r.quantityScore));

  String _formatSummaryValue(double? value) {
    if (value == null) return 'No ratings yet';
    return value.toStringAsFixed(1);
  }

  List<RatingModel> _filteredRatings(List<RatingModel> ratings) {
    if (_selectedMaterial == 'All') return ratings;
    return ratings
        .where((r) => r.materialName == _selectedMaterial)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: const SupplierAppBar(title: 'My Ratings'),
      body: Consumer<SupplierViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading && viewModel.ratings.isEmpty) {
            return const SupplierListSkeleton(itemCount: 4, itemHeight: 120);
          }

          final allRatings = viewModel.ratings;
          final filteredRatings = _filteredRatings(allRatings);
          final materialOptions = [
            'All',
            ...allRatings
                .map((r) => r.materialName)
                .where((name) => name.trim().isNotEmpty)
                .toSet(),
          ];
          final dropdownValue =
              materialOptions.contains(_selectedMaterial) ? _selectedMaterial : 'All';

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildSummaryCard(
                      'Overall',
                      _formatSummaryValue(_avgOverall(allRatings)),
                      Icons.star,
                    ),
                    _buildSummaryCard(
                      'Quality',
                      _formatSummaryValue(_avgQuality(allRatings)),
                      Icons.high_quality,
                    ),
                    _buildSummaryCard(
                      'Packaging',
                      _formatSummaryValue(_avgPackaging(allRatings)),
                      Icons.inventory_2,
                    ),
                    _buildSummaryCard(
                      'Quantity',
                      _formatSummaryValue(_avgQuantity(allRatings)),
                      Icons.scale,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonFormField<String>(
                  value: dropdownValue,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Material',
                  ),
                  items: materialOptions
                      .map<DropdownMenuItem<String>>(
                        (m) => DropdownMenuItem<String>(
                          value: m,
                          child: Text(m, style: AppTextStyles.body),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedMaterial = val);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filteredRatings.isEmpty
                    ? SupplierEmptyState(
                        icon: Icons.star_outline,
                        title: _selectedMaterial == 'All'
                            ? 'No ratings yet'
                            : 'No ratings for this material',
                        subtitle: _selectedMaterial == 'All'
                            ? 'Customer ratings will appear here after orders are completed'
                            : 'Try selecting a different material from the filter above',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredRatings.length,
                        itemBuilder: (context, index) {
                          return _buildRatingCard(filteredRatings[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon) {
    final isEmptyLabel = value == 'No ratings yet';

    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: FieldColors.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              Icon(icon, size: 20, color: FieldColors.primaryNavy),
              const SizedBox(height: 8),
              Text(
                value,
                style: (isEmptyLabel ? AppTextStyles.caption : AppTextStyles.h3)
                    .copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isEmptyLabel ? 9 : 16,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(fontSize: 9),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingCard(RatingModel rating) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: const BorderSide(color: FieldColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  rating.userName.isNotEmpty ? rating.userName : 'Field User',
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  DateFormat('MMM dd, yyyy').format(rating.createdAt),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              rating.materialName,
              style: AppTextStyles.caption.copyWith(
                color: FieldColors.primaryNavy,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Divider(height: 24),
            _starRow('Quality', rating.qualityScore),
            _starRow('Packaging', rating.packagingScore),
            _starRow('Quantity', rating.quantityScore),
            _starRow('Timeliness', rating.timelinessScore),
            if (rating.comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                rating.comment,
                style: AppTextStyles.bodyMuted.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _starRow(String label, double score) {
    final filledStars = score.round().clamp(0, 5);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: AppTextStyles.caption),
          ),
          ...List.generate(
            5,
            (index) => Icon(
              index < filledStars ? Icons.star : Icons.star_border,
              size: 14,
              color: FieldColors.statusWarning,
            ),
          ),
        ],
      ),
    );
  }
}
