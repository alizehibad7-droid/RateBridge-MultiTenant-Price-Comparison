import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/route_names.dart';
import '../../models/category_model.dart';
import '../../theme/field_theme.dart';
import '../../viewmodels/field_user/field_catalog_viewmodel.dart';
import '../../viewmodels/field_user/field_session_viewmodel.dart';
import 'widgets/field_material_card.dart';
import 'widgets/field_material_grid_skeleton.dart';
import 'widgets/field_async_states.dart';

class FieldCategoriesView extends StatefulWidget {
  const FieldCategoriesView({super.key});

  @override
  State<FieldCategoriesView> createState() => _FieldCategoriesViewState();
}

class _FieldCategoriesViewState extends State<FieldCategoriesView> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _searchController.addListener(() {
      setState(() => _query = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final companyId = context.read<FieldSessionViewModel>().companyId;
    if (companyId == null) return;
    await context.read<FieldCatalogViewModel>().loadCategoriesBrowse(companyId);
  }

  Future<void> _refresh() async {
    final companyId = context.read<FieldSessionViewModel>().companyId;
    if (companyId == null) return;
    await context.read<FieldCatalogViewModel>().loadCategoriesBrowse(companyId);
  }

  void _openCategory(CategoryModel category) {
    context.push(
      RouteNames.fieldCategory.replaceFirst(
        ':categoryName',
        Uri.encodeComponent(category.name),
      ),
    );
  }

  List<CategoryModel> _filteredCategories(List<CategoryModel> categories) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return categories;
    return categories
        .where((category) => category.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<FieldCatalogViewModel>();
    final categories = catalog.browseCategories;
    final filtered = _filteredCategories(categories);

    return Theme(
      data: FieldTheme.theme,
      child: Scaffold(
        backgroundColor: FieldColors.screenBackground,
        appBar: const FieldAppBar(title: 'All Categories'),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FieldSpacing.lg,
                FieldSpacing.sm,
                FieldSpacing.lg,
                FieldSpacing.md,
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search categories',
                  prefixIcon: Icon(Icons.search, color: FieldColors.textMuted),
                ),
              ),
            ),
            Expanded(
              child: catalog.errorMessage != null && categories.isEmpty
                  ? FieldErrorState(
                      title: 'Could not load categories',
                      message: catalog.errorMessage!,
                      onRetry: _load,
                    )
                  : catalog.isLoading && categories.isEmpty
                  ? const FieldMaterialGridSkeleton()
                  : categories.isEmpty
                      ? const FieldEmptyState(
                          icon: Icons.category_outlined,
                          title: 'No categories available yet',
                          subtitle:
                              'Categories will appear once materials are added.',
                        )
                      : filtered.isEmpty
                          ? FieldEmptyState(
                              icon: Icons.search_off_outlined,
                              title: 'No categories match "${_query.trim()}"',
                              action: OutlinedButton(
                                onPressed: () => _searchController.clear(),
                                child: const Text('Clear search'),
                              ),
                            )
                          : RefreshIndicator(
                              color: FieldColors.primaryNavy,
                              onRefresh: _refresh,
                              child: GridView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  FieldSpacing.lg,
                                  0,
                                  FieldSpacing.lg,
                                  FieldSpacing.lg,
                                ),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: FieldSpacing.md,
                                  crossAxisSpacing: FieldSpacing.md,
                                  childAspectRatio: 0.92,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final category = filtered[index];
                                  final count = catalog.materialCountForCategory(
                                    category.name,
                                  );
                                  return _CategoryBrowseCard(
                                    category: category,
                                    materialCount: count,
                                    showCount: count > 0,
                                    onTap: () => _openCategory(category),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBrowseCard extends StatelessWidget {
  final CategoryModel category;
  final int materialCount;
  final bool showCount;
  final VoidCallback onTap;

  const _CategoryBrowseCard({
    required this.category,
    required this.materialCount,
    required this.showCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FieldRadius.card),
        child: Ink(
          decoration: FieldTheme.cardDecoration(),
          padding: const EdgeInsets.all(FieldSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: FieldColors.accentAmber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  fieldMaterialCategoryIcon(category.name),
                  color: FieldColors.primaryNavy,
                  size: 22,
                ),
              ),
              const Spacer(),
              Text(
                category.name,
                style: FieldTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (showCount) ...[
                const SizedBox(height: FieldSpacing.xs),
                Text(
                  materialCount == 1
                      ? '1 material'
                      : '$materialCount materials',
                  style: FieldTypography.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
