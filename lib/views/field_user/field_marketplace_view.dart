import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';
import '../../viewmodels/field_order_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/voice_search_button_widget.dart';
import '../../models/material_model.dart';
import '../../models/material_listing.dart';

class FieldMarketplaceView extends StatefulWidget {
  const FieldMarketplaceView({super.key});

  @override
  State<FieldMarketplaceView> createState() => _FieldMarketplaceViewState();
}

class _FieldMarketplaceViewState extends State<FieldMarketplaceView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVM = context.read<AuthViewModel>();
      if (authVM.user != null) {
        context.read<FieldOrderViewModel>().loadMarketplace(authVM.user!.companyId);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Marketplace', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {}); // Trigger rebuild for suffix icon
                context.read<FieldOrderViewModel>().filterMaterials(val);
              },
              decoration: InputDecoration(
                hintText: 'Search materials (Steel, Cement...)',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        context.read<FieldOrderViewModel>().filterMaterials('');
                      },
                    )
                  : null,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Consumer<FieldOrderViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) return const Center(child: CircularProgressIndicator());
          
          if (viewModel.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(viewModel.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      final authVM = context.read<AuthViewModel>();
                      if (authVM.user != null) {
                        viewModel.loadMarketplace(authVM.user!.companyId);
                      }
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (viewModel.marketplaceMaterials.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text('No materials found', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              final authVM = context.read<AuthViewModel>();
              if (authVM.user != null) {
                await viewModel.loadMarketplace(authVM.user!.companyId);
              }
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: viewModel.marketplaceMaterials.length,
              itemBuilder: (context, index) {
                final material = viewModel.marketplaceMaterials[index];
                return _buildMaterialCard(context, material);
              },
            ),
          );
        },
      ),
      floatingActionButton: VoiceSearchButtonWidget(
        onTranscriptRecognized: (text) {
          setState(() => _searchController.text = text);
          context.read<FieldOrderViewModel>().filterMaterials(text);
        },
      ),
    );
  }

  Widget _buildMaterialCard(BuildContext context, MaterialModel material) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final listing = MaterialListing(
            id: material.id,
            materialName: material.name,
            supplierName: material.supplierName,
            supplierId: material.supplierId,
            pricePerUnit: material.pricePerUnit,
            unit: material.unit,
            category: material.category,
            supplierRating: 4.5, 
            stock: 100, 
          );
          context.push(RouteNames.fieldPlaceOrder, extra: listing);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Center(
                  child: Icon(
                    _getIconForCategory(material.category),
                    size: 40, 
                    color: AppColors.primary.withOpacity(0.4)
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    material.supplierName,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rs. ${material.pricePerUnit.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: AppColors.primary,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '/${material.unit}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'cement': return Icons.layers_outlined;
      case 'steel': return Icons.architecture_outlined;
      case 'aggregates': return Icons.grid_view_outlined;
      case 'sand': return Icons.grain;
      default: return Icons.construction;
    }
  }
}
