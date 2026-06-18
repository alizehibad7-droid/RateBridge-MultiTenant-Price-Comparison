// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../constants/app_colors.dart';
import 'package:intl/intl.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Ratings', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Consumer<SupplierViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading && viewModel.ratings.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Generate unique material list for filter
          final materials = ['All', ...viewModel.materials.map((m) => m.name).toSet()];

          return Column(
            children: [
              // Summary row 4 cards
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    _buildSummaryCard('Overall', '4.8', Icons.star),
                    _buildSummaryCard('Quality', '4.9', Icons.high_quality),
                    _buildSummaryCard('Packaging', '4.7', Icons.inventory_2),
                    _buildSummaryCard('Quantity', '4.8', Icons.scale),
                  ],
                ),
              ),

              // Material filter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: DropdownButtonFormField<String>(
                  value: _selectedMaterial,
                  decoration: const InputDecoration(labelText: 'Filter by Material'),
                  items: materials.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedMaterial = val);
                      viewModel.filterRatingsByMaterial(val);
                    }
                  },
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: viewModel.ratings.isEmpty
                    ? const Center(child: Text('No ratings yet', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: viewModel.ratings.length,
                        itemBuilder: (context, index) {
                          final rating = viewModel.ratings[index];
                          return _buildRatingCard(rating);
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
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingCard(dynamic rating) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(rating.userName ?? 'Field User', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(DateFormat('MMM dd, yyyy').format(rating.createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Text(rating.materialName, style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
            const Divider(height: 24),
            _starRow('Quality', rating.qualityScore),
            _starRow('Packaging', rating.packagingScore),
            _starRow('Quantity', rating.quantityScore),
            _starRow('Timeliness', rating.timelinessScore),
            if (rating.comment != null && rating.comment!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(rating.comment!, style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _starRow(String label, double score) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey))),
          ...List.generate(5, (index) => Icon(
            index < score ? Icons.star : Icons.star_border,
            size: 14,
            color: Colors.amber,
          )),
        ],
      ),
    );
  }
}
