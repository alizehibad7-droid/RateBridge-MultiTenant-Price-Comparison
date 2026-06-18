import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/material_model.dart';
import '../../widgets/material_card_widget.dart';
import '../../constants/route_names.dart';
import '../../constants/app_colors.dart';

class FieldSearchResultsView extends StatefulWidget {
  const FieldSearchResultsView({super.key});

  @override
  State<FieldSearchResultsView> createState() => _FieldSearchResultsViewState();
}

class _FieldSearchResultsViewState extends State<FieldSearchResultsView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<MaterialModel> _results = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('recent_searches') ?? [];
    });
  }

  Future<void> _saveSearch(String query) async {
    if (query.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 5) _recentSearches = _recentSearches.sublist(0, 5);
    await prefs.setStringList('recent_searches', _recentSearches);
    _loadRecentSearches();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _results = [];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _isSearching = false;
      _results = [
        MaterialModel(
          id: 'search_1',
          name: '$query Premium Sourcing',
          category: 'Cement',
          pricePerUnit: 1500,
          unit: 'Bag',
          specifications: 'High strength industrial grade',
          qualityGrade: 'A+',
          supplierId: 'sup_1',
          supplierName: 'Global Enterprise Network',
          isCertified: true,
          originCity: 'Karachi',
        ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
          decoration: const InputDecoration(
            hintText: "Search high-integrity materials...",
            hintStyle: TextStyle(color: AppColors.textSecondary),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            fillColor: Colors.transparent,
            filled: false,
          ),
          onChanged: _onSearchChanged,
          onSubmitted: _saveSearch,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
          : _searchController.text.isEmpty
              ? _buildRecentSearches(theme)
              : _results.isEmpty
                  ? _buildEmptyState(theme)
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final material = _results[index];
                        final navigationUrl = RouteNames.fieldCompare.replaceFirst(':materialId', material.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _PressableScale(
                            onTap: () => context.push(navigationUrl),
                            child: MaterialCardWidget(
                              material: material,
                              onTap: () => context.push(navigationUrl),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _buildRecentSearches(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      children: [
        if (_recentSearches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              "RECENT QUERIES", 
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800, 
                letterSpacing: 1.5,
                fontSize: 10,
              ),
            ),
          ),
          ..._recentSearches.map((s) => ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Icons.history_rounded, color: AppColors.textSecondary, size: 20),
                title: Text(s, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
                trailing: const Icon(Icons.north_west_rounded, color: AppColors.border, size: 18),
                onTap: () {
                  _searchController.text = s;
                  _performSearch(s);
                },
              )),
          const SizedBox(height: 32),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            "MARKET SUGGESTIONS", 
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800, 
              letterSpacing: 1.5,
              fontSize: 10,
            ),
          ),
        ),
        _buildSuggestionTile("Industrial Grade Steel"),
        _buildSuggestionTile("OPC Cement - 50kg"),
        _buildSuggestionTile("Aggregates & Sand"),
      ],
    );
  }

  Widget _buildSuggestionTile(String label) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: const Icon(Icons.trending_up_rounded, color: AppColors.primary, size: 20),
      title: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 14)),
      onTap: () {
        _searchController.text = label;
        _performSearch(label);
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
            child: const Icon(Icons.search_off_rounded, size: 40, color: AppColors.textSecondary, weight: 200),
          ),
          const SizedBox(height: 24),
          Text(
            "No matching materials", 
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            "Try refining your search parameters.", 
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}

class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableScale({required this.child, required this.onTap});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
