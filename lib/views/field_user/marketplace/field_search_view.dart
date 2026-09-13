import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/app_constants.dart';
import '../../../constants/route_names.dart';
import '../../../models/category_model.dart';
import '../../../models/material_model.dart';
import '../../../services/recently_viewed_service.dart';
import '../../../theme/field_theme.dart';
import '../../../utils/app_navigation.dart';
import '../../../viewmodels/field_user/field_catalog_viewmodel.dart';
import '../../../viewmodels/field_user/field_session_viewmodel.dart';
import '../widgets/field_material_card.dart';
import '../widgets/field_async_states.dart';

class FieldSearchView extends StatefulWidget {
  const FieldSearchView({super.key});

  @override
  State<FieldSearchView> createState() => _FieldSearchViewState();
}

class _FieldSearchViewState extends State<FieldSearchView> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  List<String> _recentSearches = [];
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final session = context.read<FieldSessionViewModel>();
    final catalog = context.read<FieldCatalogViewModel>();
    await _loadRecentSearches();
    if (!mounted) return;

    final companyId = session.companyId;
    if (companyId != null) {
      if (!catalog.hasCachedMaterials) {
        await catalog.loadMarketplace(companyId);
      } else if (catalog.categories.isEmpty) {
        await catalog.loadMarketplace(companyId);
      }
    }
    if (!mounted) return;
    setState(() => _initialized = true);
    _focusNode.requestFocus();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = context.read<SharedPreferences>();
    setState(() {
      _recentSearches =
          prefs.getStringList(AppConstants.prefsRecentSearchesKey) ?? [];
    });
  }

  Future<void> _saveRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final prefs = context.read<SharedPreferences>();
    final updated = [trimmed, ..._recentSearches.where((s) => s != trimmed)];
    if (updated.length > 8) updated.removeRange(8, updated.length);
    await prefs.setStringList(AppConstants.prefsRecentSearchesKey, updated);
    if (mounted) setState(() => _recentSearches = updated);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(AppConstants.searchDebounce, () {
      context.read<FieldCatalogViewModel>().searchLocalMaterials(value);
      if (value.trim().isNotEmpty) {
        _saveRecentSearch(value.trim());
      }
    });
    setState(() {});
  }

  void _applyQuery(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    context.read<FieldCatalogViewModel>().searchLocalMaterials(query);
    if (query.trim().isNotEmpty) {
      _saveRecentSearch(query.trim());
    }
    setState(() {});
  }

  void _openCompare(MaterialModel material) {
    context.read<RecentlyViewedService>().persistView(material.id);
    context.push(
      RouteNames.fieldCompareOf(material.name),
      extra: material.name,
    );
  }

  void _openCategoryMarketplace(String categoryName) {
    context.push(
      '${RouteNames.fieldMarketplace}?category=${Uri.encodeComponent(categoryName)}',
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<FieldCatalogViewModel>();
    final query = _controller.text;
    final hasQuery = query.trim().isNotEmpty;

    return Theme(
      data: FieldTheme.theme,
      child: Scaffold(
        backgroundColor: FieldColors.screenBackground,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FieldSpacing.sm,
                  FieldSpacing.sm,
                  FieldSpacing.lg,
                  FieldSpacing.md,
                ),
                child: Row(
                  children: [
                    AppBackButton(color: FieldColors.primaryNavy),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        onChanged: _onQueryChanged,
                        textInputAction: TextInputAction.search,
                        style: FieldTypography.bodyLarge,
                        decoration: FieldTheme.fieldDecoration(
                          hintText: 'Search materials...',
                        ).copyWith(
                          prefixIcon: const Icon(
                            Icons.search,
                            color: FieldColors.textSecondary,
                          ),
                          suffixIcon: query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    _controller.clear();
                                    catalog.clearSearchResults();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: !_initialized
                    ? const FieldLoadingState(message: 'Loading search…')
                    : hasQuery
                        ? _SearchResultsList(
                            results: catalog.searchResults,
                            query: query.trim(),
                            onMaterialTap: _openCompare,
                          )
                        : _SearchIdleContent(
                            recentSearches: _recentSearches,
                            categories: catalog.browseCategories,
                            onRecentTap: _applyQuery,
                            onCategoryTap: _openCategoryMarketplace,
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchIdleContent extends StatelessWidget {
  final List<String> recentSearches;
  final List<CategoryModel> categories;
  final ValueChanged<String> onRecentTap;
  final ValueChanged<String> onCategoryTap;

  const _SearchIdleContent({
    required this.recentSearches,
    required this.categories,
    required this.onRecentTap,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: FieldSpacing.lg),
      children: [
        if (recentSearches.isNotEmpty) ...[
          Text(
            'RECENT SEARCHES',
            style: FieldTypography.labelSmall,
          ),
          const SizedBox(height: FieldSpacing.sm),
          ...recentSearches.map(
            (term) => _RecentSearchTile(
              term: term,
              onTap: () => onRecentTap(term),
            ),
          ),
          const SizedBox(height: FieldSpacing.xl),
        ],
        Text(
          'POPULAR CATEGORIES',
          style: FieldTypography.labelSmall,
        ),
        const SizedBox(height: FieldSpacing.sm),
        if (categories.isEmpty)
          Text(
            'No categories available.',
            style: FieldTypography.bodyMedium,
          )
        else
          Wrap(
            spacing: FieldSpacing.sm,
            runSpacing: FieldSpacing.sm,
            children: categories.map((category) {
              return ActionChip(
                label: Text(category.name),
                backgroundColor: FieldColors.surfaceWhite,
                side: const BorderSide(color: FieldColors.borderSubtle),
                labelStyle: FieldTypography.bodyMedium.copyWith(
                  color: FieldColors.textPrimary,
                ),
                onPressed: () => onCategoryTap(category.name),
              );
            }).toList(),
          ),
        const SizedBox(height: FieldSpacing.xl),
      ],
    );
  }
}

class _RecentSearchTile extends StatelessWidget {
  final String term;
  final VoidCallback onTap;

  const _RecentSearchTile({required this.term, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FieldRadius.button),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: FieldSpacing.sm),
          child: Row(
            children: [
              const Icon(Icons.history, size: 18, color: FieldColors.textMuted),
              const SizedBox(width: FieldSpacing.sm),
              Expanded(
                child: Text(term, style: FieldTypography.bodyLarge),
              ),
              const Icon(Icons.north_west, size: 16, color: FieldColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  final List<MaterialModel> results;
  final String query;
  final ValueChanged<MaterialModel> onMaterialTap;

  const _SearchResultsList({
    required this.results,
    required this.query,
    required this.onMaterialTap,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return FieldEmptyState(
        icon: Icons.search_off_outlined,
        title: 'No results found',
        subtitle: 'No materials found for "$query". Try a different search term.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        FieldSpacing.lg,
        0,
        FieldSpacing.lg,
        FieldSpacing.lg,
      ),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: FieldSpacing.sm),
      itemBuilder: (context, index) {
        final material = results[index];
        return FieldSearchResultTile(
          material: material,
          onTap: () => onMaterialTap(material),
        );
      },
    );
  }
}
