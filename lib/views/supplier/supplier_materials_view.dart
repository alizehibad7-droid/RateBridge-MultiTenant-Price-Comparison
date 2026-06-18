// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../models/material_model.dart';
import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';
import '../../utils/currency_formatter.dart';

class SupplierMaterialsView extends StatefulWidget {
  const SupplierMaterialsView({super.key});

  @override
  State<SupplierMaterialsView> createState() => _SupplierMaterialsViewState();
}

class _SupplierMaterialsViewState extends State<SupplierMaterialsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<SupplierViewModel>();
      if (viewModel.selectedCompanyId != null) {
        viewModel.loadMaterials(viewModel.selectedCompanyId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Materials', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RouteNames.supplierAddMaterial),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Consumer<SupplierViewModel>(
        builder: (context, vm, child) {
          if (vm.isLoading && vm.materials.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (vm.materials.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No materials yet. Tap + to add.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vm.materials.length,
            itemBuilder: (context, index) {
              final material = vm.materials[index];
              return _buildMaterialCard(vm, material);
            },
          );
        },
      ),
    );
  }

  Widget _buildMaterialCard(SupplierViewModel viewModel, MaterialModel material) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
        ),
        title: Text(material.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(CurrencyFormatter.formatPKR(material.pricePerUnit), 
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSpecChip(material.unit),
                      const SizedBox(width: 8),
                      _buildSpecChip(material.brand ?? 'Generic'),
                      const SizedBox(width: 8),
                      _buildSpecChip(material.grade),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.push(
                            RouteNames.supplierEditMaterial.replaceFirst(':matId', material.id),
                            extra: material,
                          );
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          foregroundColor: Colors.black,
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmDelete(viewModel, material),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red,
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Price History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                _buildPriceHistoryPlaceholder(),
                const SizedBox(height: 16),
                const Text('Customer Feedback', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                const Text('No feedback yet', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPriceHistoryPlaceholder() {
    return Column(
      children: [
        _priceRow('Oct 25', 'Rs. 45,000', '+2%', Colors.red),
        _priceRow('Oct 10', 'Rs. 44,100', '-1%', Colors.green),
      ],
    );
  }

  Widget _priceRow(String date, String price, String change, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(price, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          Text(change, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _confirmDelete(SupplierViewModel viewModel, MaterialModel material) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Material'),
        content: Text('Are you sure you want to delete ${material.name}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (viewModel.selectedCompanyId != null) {
                await viewModel.deleteMaterial(material.id, viewModel.selectedCompanyId!);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
}
