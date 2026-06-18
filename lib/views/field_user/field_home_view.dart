import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/field_user_viewmodel.dart';
import '../../viewmodels/field_order_viewmodel.dart';
import '../../widgets/field/field_widgets.dart';
import '../../widgets/voice_search_button_widget.dart';
import '../../models/material_model.dart';
import '../../models/material_listing.dart';

class FieldHomeView extends StatefulWidget {
  const FieldHomeView({super.key});

  @override
  State<FieldHomeView> createState() => _FieldHomeViewState();
}

class _FieldHomeViewState extends State<FieldHomeView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVM = context.read<AuthViewModel>();
      if (authVM.user != null) {
        context.read<FieldUserViewModel>().loadUserData(authVM.user!.uid);
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
        title: const Text('Field Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => context.push(RouteNames.fieldNotifications),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push(RouteNames.fieldProfile),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer2<FieldUserViewModel, FieldOrderViewModel>(
        builder: (context, userVM, orderVM, child) {
          if (userVM.isLoading && userVM.user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async {
              await userVM.refreshHome();
              if (userVM.user != null) {
                await orderVM.loadMarketplace(userVM.user!.companyId);
              }
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildWelcomeSection(userVM),
                const SizedBox(height: 20),
                _buildSearchField(orderVM),
                const SizedBox(height: 24),
                _buildStatsGrid(userVM),
                const SizedBox(height: 32),
                const Text('Marketplace', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildMarketplaceGrid(orderVM),
                const SizedBox(height: 32),
                const Text('Active Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (userVM.recentOrders.isEmpty)
                  _buildEmptyOrdersPlaceholder()
                else
                  ...userVM.recentOrders.map((order) => FieldOrderTile(
                    order: order,
                    onTap: () => context.push(RouteNames.fieldOrderDetail.replaceFirst(':orderId', order.orderId)),
                  )),
                const SizedBox(height: 80), // Space for FAB
              ],
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

  Widget _buildWelcomeSection(FieldUserViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back,',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        Text(
          viewModel.user?.name ?? 'Field User',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.fieldAccent),
        ),
      ],
    );
  }

  Widget _buildSearchField(FieldOrderViewModel viewModel) {
    return TextField(
      controller: _searchController,
      onChanged: (val) {
        setState(() {}); 
        viewModel.filterMaterials(val);
      },
      decoration: InputDecoration(
        hintText: 'Search materials (Steel, Cement...)',
        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
        suffixIcon: _searchController.text.isNotEmpty 
          ? IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: () {
                _searchController.clear();
                setState(() {});
                viewModel.filterMaterials('');
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
    );
  }

  Widget _buildStatsGrid(FieldUserViewModel viewModel) {
    final orders = viewModel.myOrders;
    final pendingCount = orders.where((o) => o.status.toLowerCase().contains('pending')).length;
    final activeCount = orders.where((o) => o.status == 'accepted' || o.status == 'inProgress').length;
    final deliveredCount = orders.where((o) => o.status == 'delivered' || o.status == 'confirmed').length;

    return Row(
      children: [
        _buildStatCard('Pending', pendingCount.toString(), Colors.blue),
        const SizedBox(width: 12),
        _buildStatCard('Active', activeCount.toString(), Colors.orange),
        const SizedBox(width: 12),
        _buildStatCard('Delivered', deliveredCount.toString(), Colors.green),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketplaceGrid(FieldOrderViewModel viewModel) {
    if (viewModel.isLoading) return const Center(child: CircularProgressIndicator());
    
    if (viewModel.marketplaceMaterials.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text('No materials found', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: viewModel.marketplaceMaterials.length > 4 ? 4 : viewModel.marketplaceMaterials.length,
      itemBuilder: (context, index) {
        final material = viewModel.marketplaceMaterials[index];
        return _buildMaterialCard(context, material);
      },
    );
  }

  Widget _buildMaterialCard(BuildContext context, MaterialModel material) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final listing = MaterialListing(
            id: material.id,
            materialName: material.name,
            supplierName: material.supplierName,
            supplierId: material.supplierId,
            pricePerUnit: material.pricePerUnit,
            unit: material.unit,
            category: material.category,
          );
          context.push(RouteNames.fieldPlaceOrder, extra: listing);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_getIconForCategory(material.category), color: AppColors.fieldAccent, size: 24),
              const Spacer(),
              Text(material.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(material.supplierName, style: TextStyle(color: Colors.grey[600], fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('Rs. ${material.pricePerUnit.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.fieldAccent, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'cement': return Icons.layers_outlined;
      case 'steel': return Icons.architecture_outlined;
      case 'sand': return Icons.grain;
      default: return Icons.construction;
    }
  }

  Widget _buildEmptyOrdersPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(Icons.assignment_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No active orders', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
