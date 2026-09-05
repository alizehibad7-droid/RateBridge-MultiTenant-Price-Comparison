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
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AdminColors.navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AdminColors.navy, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AdminColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Unit: ${category.unit}  ·  ${category.brands.length} Brands',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdminTheme.mutedStyle(size: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 32,
                child: Switch(
                  value: category.isActive,
                  activeTrackColor: AdminColors.amber.withValues(alpha: 0.55),
                  activeThumbColor: AdminColors.amber,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) async {
                    try {
                      await adminVM.setCategoryActive(category.id, value);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not update category: $e')),
                      );
                    }
                  },
                ),
              ),
              Text(
                category.isActive ? 'ACTIVE' : 'INACTIVE',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: category.isActive
                      ? AdminColors.green
                      : AdminColors.textGrey,
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Edit Specifications',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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

  void _showCategoryFormDialog(
    BuildContext context,
    CategoryModel? existing,
    AdminViewModel adminVM,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => _CategoryFormDialog(
        existing: existing,
        adminVM: adminVM,
      ),
    );
  }
}

class _CategoryFormDialog extends StatefulWidget {
  final CategoryModel? existing;
  final AdminViewModel adminVM;

  const _CategoryFormDialog({
    required this.existing,
    required this.adminVM,
  });

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _brandsController;
  late final TextEditingController _gradesController;
  bool _saving = false;
  String? _error;

  bool get _isNew => widget.existing == null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _unitController = TextEditingController(text: existing?.unit ?? '');
    _brandsController = TextEditingController(
      text: existing?.brands.join(', ') ?? '',
    );
    _gradesController = TextEditingController(
      text: existing?.grades.join(', ') ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _brandsController.dispose();
    _gradesController.dispose();
    super.dispose();
  }

  List<String> _parseList(String raw) {
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final unit = _unitController.text.trim();
    if (_isNew && name.isEmpty) {
      setState(() => _error = 'Category name is required');
      return;
    }
    if (unit.isEmpty) {
      setState(() => _error = 'Unit of measure is required');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final brands = _parseList(_brandsController.text);
      final grades = _parseList(_gradesController.text);
      if (_isNew) {
        await widget.adminVM.addCategory(name, unit, brands, grades);
      } else {
        await widget.adminVM.editCategory(
          widget.existing!.id,
          widget.existing!.name,
          unit,
          brands,
          grades,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save category. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Row(
        children: [
          Icon(
            _isNew ? Icons.add_business_rounded : Icons.edit_note_rounded,
            color: AdminColors.navy,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isNew ? 'New Category' : 'Edit Category',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GENERAL INFO', style: AdminTheme.sectionHeaderStyle()),
              const SizedBox(height: 12),
              if (_isNew)
                TextField(
                  controller: _nameController,
                  decoration: AdminTheme.inputDecoration(
                    labelText: 'Category Name',
                    prefixIcon: const Icon(Icons.label_outline_rounded),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AdminColors.screenBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: AdminColors.textGrey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.existing!.name,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: AdminColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _unitController,
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
                controller: _brandsController,
                decoration: AdminTheme.inputDecoration(
                  labelText: 'Available Brands',
                  hintText: 'Separate with commas',
                  prefixIcon: const Icon(Icons.branding_watermark_outlined),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _gradesController,
                decoration: AdminTheme.inputDecoration(
                  labelText: 'Grades or Types',
                  hintText: 'Leave empty if not applicable',
                  prefixIcon: const Icon(Icons.grade_outlined),
                ),
                maxLines: 2,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: AdminTheme.bodyStyle(color: AdminColors.red)
                      .copyWith(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded, size: 18),
          label: Text(_isNew ? 'CREATE' : 'SAVE CHANGES'),
          style: AdminTheme.primaryButtonStyle(height: 44).copyWith(
            minimumSize: WidgetStateProperty.all(const Size(0, 44)),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }
}
