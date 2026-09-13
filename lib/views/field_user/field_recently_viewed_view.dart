import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../constants/route_names.dart';
import '../../models/material_model.dart';
import '../../services/recently_viewed_service.dart';
import '../../theme/field_theme.dart';
import '../../viewmodels/field_user/field_catalog_viewmodel.dart';
import '../../viewmodels/field_user/field_session_viewmodel.dart';
import 'widgets/field_material_card.dart';
import 'widgets/field_material_grid_skeleton.dart';

class FieldRecentlyViewedView extends StatefulWidget {
  const FieldRecentlyViewedView({super.key});

  @override
  State<FieldRecentlyViewedView> createState() =>
      _FieldRecentlyViewedViewState();
}

class _FieldRecentlyViewedViewState extends State<FieldRecentlyViewedView> {
  List<MaterialModel> _materials = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final session = context.read<FieldSessionViewModel>();
    final companyId = session.companyId;
    final catalog = context.read<FieldCatalogViewModel>();
    final ids = await context.read<RecentlyViewedService>().readRecentIds();
    if (!mounted) return;

    if (ids.isEmpty || companyId == null) {
      setState(() {
        _materials = [];
        _loading = false;
      });
      return;
    }

    await catalog.loadRecentlyViewedMaterials(companyId, ids);

    if (!mounted) return;
    setState(() {
      _materials = catalog.recentlyViewedMaterials;
      _loading = false;
    });
  }

  Future<void> _clearHistory() async {
    final catalog = context.read<FieldCatalogViewModel>();
    await context.read<RecentlyViewedService>().wipeHistory();
    catalog.clearRecentlyViewedDisplay();
    if (!mounted) return;
    setState(() => _materials = []);
  }

  void _openCompare(MaterialModel material) {
    context.read<RecentlyViewedService>().persistView(material.id);
    context.push(
      RouteNames.fieldCompareOf(material.name),
      extra: material.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: FieldTheme.theme,
      child: Scaffold(
        backgroundColor: FieldColors.screenBackground,
        appBar: FieldAppBar(
          title: 'Recently Viewed',
          actions: [
            if (_materials.isNotEmpty)
              TextButton(
                onPressed: _clearHistory,
                child: Text(
                  'Clear',
                  style: FieldTypography.bodyMedium.copyWith(
                    color: FieldColors.accentAmber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        body: _loading && _materials.isEmpty
            ? const FieldMaterialGridSkeleton()
            : _materials.isEmpty
                ? const _RecentlyViewedEmptyState()
                : RefreshIndicator(
                    color: FieldColors.primaryNavy,
                    onRefresh: _load,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(FieldSpacing.lg),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: FieldSpacing.md,
                        crossAxisSpacing: FieldSpacing.md,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: _materials.length,
                      itemBuilder: (context, index) {
                        final material = _materials[index];
                        return FieldMaterialCard(
                          material: material,
                          onTap: () => _openCompare(material),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

class _RecentlyViewedEmptyState extends StatelessWidget {
  const _RecentlyViewedEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(FieldSpacing.xl),
        child: Text(
          'Materials you browse will appear here',
          style: FieldTypography.bodyLarge.copyWith(
            color: FieldColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
