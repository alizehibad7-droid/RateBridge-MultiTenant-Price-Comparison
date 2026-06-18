import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../constants/app_colors.dart';

class AdminCategoriesView extends StatefulWidget {
  const AdminCategoriesView({super.key});

  @override
  State<AdminCategoriesView> createState() => _AdminCategoriesViewState();
}

class _AdminCategoriesViewState extends State<AdminCategoriesView> {
  @override
  Widget build(BuildContext context) {
    final adminVM = Provider.of<AdminViewModel>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Global Taxonomy", style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: () => _showCategoryFormDialog(null, adminVM),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<CategoryModel>>(
        stream: adminVM.watchCategories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final categories = snapshot.data ?? [];

          if (categories.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: categories.length,
            itemBuilder: (context, idx) => _buildCategoryCard(categories[idx], adminVM),
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(CategoryModel category, AdminViewModel adminVM) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary)),
                      Text("Standard Unit: ${category.unit.toUpperCase()}", style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => _showCategoryFormDialog(category, adminVM),
                    icon: const Icon(Icons.edit_note_rounded, color: AppColors.textSecondary, size: 22),
                  ),
                  IconButton(
                    onPressed: () => _confirmDeleteCategory(category, adminVM),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          _buildTaxonomySection("AUTHORIZED BRANDS", category.brands, AppColors.primary),
          const SizedBox(height: 16),
          _buildTaxonomySection("SPECIFICATION GRADES", category.grades, AppColors.success),
          const Divider(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${category.activeMaterialsCount} ACTIVE MATERIALS", style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textSecondary),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTaxonomySection(String title, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.1)),
            ),
            child: Text(item, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text("No global taxonomy categories defined.", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text("Define categories that suppliers will use to list materials.", style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  void _showCategoryFormDialog(CategoryModel? existing, AdminViewModel adminVM) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final unitController = TextEditingController(text: existing?.unit ?? '');
    final brandsController = TextEditingController(text: existing?.brands.join(', ') ?? '');
    final gradesController = TextEditingController(text: existing?.grades.join(', ') ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? "Define New Category" : "Edit Taxonomy Structure", style: const TextStyle(fontWeight: FontWeight.w800)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: "Category Name (e.g. Cement)")),
              const SizedBox(height: 16),
              TextField(controller: unitController, decoration: const InputDecoration(labelText: "Unit of Measure (e.g. bag)")),
              const SizedBox(height: 16),
              TextField(controller: brandsController, decoration: const InputDecoration(labelText: "Authorized Brands (comma separated)", hintText: "Lucky, DG, Maple")),
              const SizedBox(height: 16),
              TextField(controller: gradesController, decoration: const InputDecoration(labelText: "Allowed Grades (comma separated)", hintText: "OPC, PPC, SRC")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              final brands = brandsController.text.split(',').map((e) => e.trim()).toList();
              final grades = gradesController.text.split(',').map((e) => e.trim()).toList();
              if (existing == null) {
                adminVM.addCategory(nameController.text, unitController.text, brands, grades);
              } else {
                adminVM.editCategory(existing.id, nameController.text, unitController.text, brands, grades);
              }
              Navigator.pop(context);
            },
            child: const Text("SAVE TAXONOMY"),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(CategoryModel cat, AdminViewModel adminVM) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Category?"),
        content: Text("Are you sure you want to delete ${cat.name}? This will affect all materials linked to this category."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(onPressed: () {
            adminVM.deleteCategory(cat.id);
            Navigator.pop(context);
          }, child: const Text("DELETE", style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
  }
}
