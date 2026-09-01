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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: _CategorySearchField(controller: _searchController),
            ),
            Expanded(
              child: catalog.errorMessage != null && categories.isEmpty
                  ? FieldErrorState(
                      title: 'Could not load categories',
                      message: catalog.errorMessage!,
                      onRetry: _load,
                    )
                  : catalog.isCatalogLoading && categories.isEmpty
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
                                  title:
                                      'No categories match "${_query.trim()}"',
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
                                      16,
                                      8,
                                      16,
                                      24,
                                    ),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 14,
                                      crossAxisSpacing: 14,
                                      childAspectRatio: 1.02,
                                    ),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      final category = filtered[index];
                                      return _CategoryBrowseCard(
                                        category: category,
                                        materialCount:
                                            catalog.materialCountForCategory(
                                          category.name,
                                        ),
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

class _CategorySearchField extends StatelessWidget {
  final TextEditingController controller;

  const _CategorySearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final hasQuery = controller.text.trim().isNotEmpty;

    return Material(
      color: FieldColors.surfaceWhite,
      elevation: 0,
      shadowColor: FieldColors.primaryNavy.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: FieldColors.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: FieldColors.primaryNavy.withValues(alpha: 0.07),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          style: FieldTypography.bodyLarge.copyWith(fontSize: 14),
          cursorColor: FieldColors.primaryNavy,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search cement, steel, bricks…',
            hintStyle: FieldTypography.bodyMedium.copyWith(
              color: FieldColors.textMuted,
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: FieldColors.primaryNavy,
              size: 22,
            ),
            suffixIcon: hasQuery
                ? IconButton(
                    tooltip: 'Clear',
                    onPressed: controller.clear,
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: FieldColors.textMuted,
                    ),
                  )
                : null,
            filled: true,
            fillColor: FieldColors.surfaceWhite,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: FieldColors.accentAmber,
                width: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryAccent {
  final Color background;
  final Color foreground;

  const _CategoryAccent(this.background, this.foreground);
}

_CategoryAccent _accentFor(String category) {
  final name = category.toLowerCase();
  if (name.contains('cement')) {
    return _CategoryAccent(
      FieldColors.accentAmber.withValues(alpha: 0.22),
      FieldColors.primaryNavy,
    );
  }
  if (name.contains('steel') || name.contains('tmt')) {
    return _CategoryAccent(
      FieldColors.primaryNavy.withValues(alpha: 0.10),
      FieldColors.primaryNavy,
    );
  }
  if (name.contains('sand')) {
    return _CategoryAccent(
      FieldColors.accentAmber.withValues(alpha: 0.32),
      FieldColors.statusWarning,
    );
  }
  if (name.contains('pipe')) {
    return _CategoryAccent(
      FieldColors.primaryNavy.withValues(alpha: 0.08),
      FieldColors.primaryNavy,
    );
  }
  if (name.contains('brick')) {
    return _CategoryAccent(
      FieldColors.accentAmber.withValues(alpha: 0.18),
      FieldColors.primaryNavy,
    );
  }
  if (name.contains('timber') || name.contains('wood')) {
    return _CategoryAccent(
      FieldColors.primaryNavy.withValues(alpha: 0.09),
      FieldColors.primaryNavy,
    );
  }
  return _CategoryAccent(
    FieldColors.accentAmber.withValues(alpha: 0.16),
    FieldColors.primaryNavy,
  );
}

class _CategoryBrowseCard extends StatefulWidget {
  final CategoryModel category;
  final int materialCount;
  final VoidCallback onTap;

  const _CategoryBrowseCard({
    required this.category,
    required this.materialCount,
    required this.onTap,
  });

  @override
  State<_CategoryBrowseCard> createState() => _CategoryBrowseCardState();
}

class _CategoryBrowseCardState extends State<_CategoryBrowseCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(widget.category.name);
    final count = widget.materialCount;
    final countLabel = count == 1 ? '1 material' : '$count materials';
    final hasListings = count > 0;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: FieldColors.surfaceWhite,
        elevation: _pressed ? 1 : 3,
        shadowColor: FieldColors.primaryNavy.withValues(alpha: 0.22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FieldRadius.card),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: _setPressed,
          splashColor: FieldColors.accentAmber.withValues(alpha: 0.22),
          highlightColor: FieldColors.primaryNavy.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    fieldMaterialCategoryIcon(widget.category.name),
                    color: accent.foreground,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.category.name,
                  style: FieldTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.25,
                    color: FieldColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                _MaterialCountPill(
                  label: countLabel,
                  highlighted: hasListings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MaterialCountPill extends StatelessWidget {
  final String label;
  final bool highlighted;

  const _MaterialCountPill({
    required this.label,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted
            ? FieldColors.accentAmber.withValues(alpha: 0.18)
            : FieldColors.screenBackground,
        borderRadius: BorderRadius.circular(FieldRadius.chip),
      ),
      child: Text(
        label,
        style: FieldTypography.labelSmall.copyWith(
          color: highlighted ? FieldColors.primaryNavy : FieldColors.textMuted,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
          fontSize: 11,
        ),
      ),
    );
  }
}
