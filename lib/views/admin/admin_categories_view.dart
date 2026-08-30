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
      appBar: const AdminAppBar(title: 'Taxonomy Management'),
      body: StreamBuilder<List<CategoryModel>>(
        stream: adminVM.watchCategories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final categories = snapshot.data ?? [];

          if (categories.isEmpty) {
            return _buildEmptyState(context, adminVM);
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                decoration: BoxDecoration(
                  color: AdminColors.navy.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AdminColors.navy.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AdminColors.navy, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Manage pre-loaded Pakistan construction material categories. Toggle visibility or update specifications.',
                        style: AdminTheme.mutedStyle(size: 12).copyWith(color: AdminColors.navy, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  itemCount: categories.length,
                  itemBuilder: (context, idx) =>
                      _buildCategoryRow(context, categories[idx], adminVM),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
                ),
                child: SafeArea(
                  top: false,
                  child: ElevatedButton.icon(
                    onPressed: () => _showCategoryFormDialog(context, null, adminVM),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                    label: const Text('ADD CUSTOM CATEGORY'),
                    style: AdminTheme.primaryButtonStyle(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryRow(BuildContext context, CategoryModel category, AdminViewModel adminVM) {
    final icon = category.icon;

    return AdminCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                Row(
                  children: [
                    const Icon(Icons.scale_rounded, size: 12, color: AdminColors.textGrey),
                    const SizedBox(width: 4),
                    Text(
                      'Unit: ${category.unit}',
                      style: AdminTheme.mutedStyle(size: 11),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.inventory_2_outlined, size: 12, color: AdminColors.textGrey),
                    const SizedBox(width: 4),
                    Text(
                      '${category.brands.length} Brands',
                      style: AdminTheme.mutedStyle(size: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Switch.adaptive(
                value: category.isActive,
                activeColor: AdminColors.amber,
                onChanged: (value) =>
                    adminVM.setCategoryActive(category.id, value),
              ),
              Text(category.isActive ? 'ACTIVE' : 'INACTIVE', 
                   style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, 
                   color: category.isActive ? AdminColors.green : AdminColors.textGrey)),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Edit Specifications',
            onPressed: () => _showCategoryFormDialog(context, category, adminVM),
            icon: const Icon(
              Icons.settings_suggest_rounded,
              color: AdminColors.navy,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AdminViewModel adminVM) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AdminColors.navy.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.category_rounded,
                size: 64,
                color: AdminColors.textGrey,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No categories found',
              style: AdminTheme.titleStyle(size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'The app auto-seeds construction categories on first launch. Pull to refresh or add a custom one.',
              textAlign: TextAlign.center,
              style: AdminTheme.mutedStyle(),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _showCategoryFormDialog(context, null, adminVM),
              icon: const Icon(Icons.add),
              label: const Text('Add First Category'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryFormDialog(BuildContext context, CategoryModel? existing, AdminViewModel adminVM) {
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
        title: Row(
          children: [
            Icon(isNew ? Icons.add_business_rounded : Icons.edit_note_rounded, color: AdminColors.navy),
            const SizedBox(width: 10),
            Text(isNew ? 'New Category' : 'Edit Category'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GENERAL INFO', style: AdminTheme.sectionHeaderStyle()),
              const SizedBox(height: 12),
              if (isNew)
                TextField(
                  controller: nameController,
                  decoration: AdminTheme.inputDecoration(
                    labelText: 'Category Name',
                    prefixIcon: const Icon(Icons.label_outline_rounded),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AdminColors.screenBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, size: 18, color: AdminColors.textGrey),
                      const SizedBox(width: 12),
                      Text(
                        existing.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: AdminColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: unitController,
                decoration: AdminTheme.inputDecoration(
                  labelText: 'Unit of Measure',
                  hintText: 'e.g. bag, ton, cft',
                  prefixIcon: const Icon(Icons.straighten_rounded),
                ),
              ),
              const SizedBox(height: 24),
              Text('SPECIFICATIONS', style: AdminTheme.sectionHeaderStyle()),
              const SizedBox(height: 12),
              TextField(
                controller: brandsController,
                decoration: AdminTheme.inputDecoration(
                  labelText: 'Available Brands',
                  hintText: 'Separate with commas',
                  prefixIcon: const Icon(Icons.branding_watermark_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: gradesController,
                decoration: AdminTheme.inputDecoration(
                  labelText: 'Grades or Types',
                  hintText: 'Leave empty if not applicable',
                  prefixIcon: const Icon(Icons.grade_outlined),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton.icon(
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
            icon: const Icon(Icons.save_rounded, size: 18),
            label: Text(isNew ? 'CREATE' : 'SAVE CHANGES'),
            style: AdminTheme.primaryButtonStyle(height: 44).copyWith(
              minimumSize: WidgetStateProperty.all(const Size(140, 44)),
            ),
          ),
        ],
      ),
    );
  }
}
