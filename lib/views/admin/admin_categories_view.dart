import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/category_model.dart';
import '../../theme/admin_theme.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../widgets/admin/admin_widgets.dart';

class AdminCategoriesView extends StatefulWidget {
  const AdminCategoriesView({super.key});

  @override
  State<AdminCategoriesView> createState() => _AdminCategoriesViewState();
}

class _AdminCategoriesViewState extends State<AdminCategoriesView> {
  @override
  Widget build(BuildContext context) {
    final adminVM = Provider.of<AdminViewModel>(context);

    return Scaffold(
      backgroundColor: AdminColors.screenBg,
      appBar: const AdminAppBar(title: 'Manage Categories'),
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
                  style: AdminTheme.mutedStyle(size: 13).copyWith(height: 1.4),
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
                    style: AdminTheme.secondaryButtonStyle(),
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

    return AdminCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AdminColors.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AdminColors.navy, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AdminColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unit: ${category.unit}  ·  '
                  '${category.brands.length} brands  ·  '
                  '${category.grades.length} grades',
                  style: AdminTheme.mutedStyle(size: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: category.isActive,
            activeThumbColor: AdminColors.amber,
            activeTrackColor: AdminColors.amber.withValues(alpha: 0.4),
            onChanged: (value) =>
                adminVM.setCategoryActive(category.id, value),
          ),
          IconButton(
            tooltip: 'Edit category',
            onPressed: () => _showCategoryFormDialog(category, adminVM),
            icon: const Icon(
              Icons.edit_outlined,
              color: AdminColors.textGrey,
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
              color: AdminColors.textGrey.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              'No categories in Firestore yet.',
              style: GoogleFonts.plusJakartaSans(
                color: AdminColors.textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in once — the app auto-seeds 12 Pakistan construction '
              'categories on first launch. Pull to refresh after login.',
              textAlign: TextAlign.center,
              style: AdminTheme.mutedStyle(size: 12),
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
        title: Text(isNew ? 'Add Custom Category' : 'Edit ${existing.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isNew)
                TextField(
                  controller: nameController,
                  decoration: AdminTheme.inputDecoration(
                    labelText: 'Category name',
                  ),
                )
              else
                InputDecorator(
                  decoration: AdminTheme.inputDecoration(
                    labelText: 'Category name',
                  ),
                  child: Text(
                    existing.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      color: AdminColors.navy,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: unitController,
                decoration: AdminTheme.inputDecoration(
                  labelText: 'Unit of measure',
                  hintText: 'e.g. bag, ton, cft',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: brandsController,
                decoration: AdminTheme.inputDecoration(
                  labelText: 'Brands (comma separated)',
                  hintText: 'DG Khan, Lucky, Bestway',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: gradesController,
                decoration: AdminTheme.inputDecoration(
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
            style: AdminTheme.primaryButtonStyle(height: 44),
            child: Text(isNew ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }
}
