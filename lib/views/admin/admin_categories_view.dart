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
        title: Text(
          'Manage Categories',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
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

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Text(
                  'Categories are pre-loaded for Pakistan construction materials. '
                  'Toggle active status, update brands/grades, or add a custom category when needed.',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: categories.length,
                  itemBuilder: (context, idx) =>
                      _buildCategoryRow(categories[idx], adminVM),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: OutlinedButton.icon(
                    onPressed: () => _showCategoryFormDialog(null, adminVM),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add custom category (edge case)'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryRow(CategoryModel category, AdminViewModel adminVM) {
    final icon = category.icon;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unit: ${category.unit}  ·  '
                  '${category.brands.length} brands  ·  '
                  '${category.grades.length} grades',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: category.isActive,
            activeThumbColor: AppColors.primary,
            onChanged: (value) =>
                adminVM.setCategoryActive(category.id, value),
          ),
          IconButton(
            tooltip: 'Edit category',
            onPressed: () => _showCategoryFormDialog(category, adminVM),
            icon: const Icon(
              Icons.edit_outlined,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            const Text(
              'No categories in Firestore yet.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in once — the app auto-seeds 12 Pakistan construction '
              'categories on first launch. Pull to refresh after login.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryFormDialog(CategoryModel? existing, AdminViewModel adminVM) {
    final isNew = existing == null;
    final nameController =
        TextEditingController(text: existing?.name ?? '');
    final unitController =
        TextEditingController(text: existing?.unit ?? '');
    final brandsController = TextEditingController(
      text: existing?.brands.join(', ') ?? '',
    );
    final gradesController = TextEditingController(
      text: existing?.grades.join(', ') ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isNew ? 'Add Custom Category' : 'Edit ${existing.name}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isNew)
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Category name',
                  ),
                )
              else
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Category name'),
                  child: Text(
                    existing.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(
                  labelText: 'Unit of measure',
                  hintText: 'e.g. bag, ton, cft',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: brandsController,
                decoration: const InputDecoration(
                  labelText: 'Brands (comma separated)',
                  hintText: 'DG Khan, Lucky, Bestway',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: gradesController,
                decoration: const InputDecoration(
                  labelText: 'Grades / types (comma separated)',
                  hintText: 'OPC, PPC, SRC — leave empty if not applicable',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final brands = brandsController.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              final grades = gradesController.text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              if (isNew) {
                if (nameController.text.trim().isEmpty) return;
                adminVM.addCategory(
                  nameController.text.trim(),
                  unitController.text.trim(),
                  brands,
                  grades,
                );
              } else {
                adminVM.editCategory(
                  existing.id,
                  existing.name,
                  unitController.text.trim(),
                  brands,
                  grades,
                );
              }
              Navigator.pop(context);
            },
            child: Text(isNew ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }
}
