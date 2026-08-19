import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../constants/route_names.dart';
import '../../../models/category_model.dart';
import '../../../models/material_model.dart';
import '../../../models/order_model.dart';
import '../../../services/ai_context_service.dart';
import '../../../services/gemini_service.dart';
import '../../../services/recently_viewed_service.dart';
import '../../../theme/field_theme.dart';
import '../../../utils/currency_formatter.dart';
import '../../../viewmodels/field_user/field_catalog_viewmodel.dart';
import '../../../viewmodels/field_user/field_notifications_viewmodel.dart';
import '../../../viewmodels/field_user/field_orders_viewmodel.dart';
import '../../../viewmodels/field_user/field_session_viewmodel.dart';
import '../orders/field_order_status.dart';
import '../shell/field_shell_view.dart';
import '../widgets/field_async_states.dart';
import '../widgets/field_material_card.dart';

class FieldHomeView extends StatefulWidget {
  const FieldHomeView({super.key});

  @override
  State<FieldHomeView> createState() => _FieldHomeViewState();
}

class _FieldHomeViewState extends State<FieldHomeView> {
  bool _initialized = false;
  bool _loadingHome = false;
  String? _homeAiGreeting;

  static const _navyGradient = LinearGradient(
    colors: [FieldColors.primaryNavy, FieldColors.primaryNavyDark],
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHome());
  }

  Future<void> _loadHome() async {
    if (_loadingHome || _initialized) return;

    final session = context.read<FieldSessionViewModel>();
    final catalog = context.read<FieldCatalogViewModel>();
    final orders = context.read<FieldOrdersViewModel>();
    final companyId = session.companyId;
    final uid = session.user?.uid;
    if (companyId == null || uid == null) return;

    _loadingHome = true;
    try {
      final recentIdsFuture = RecentlyViewedService.getRecentIds();
      await catalog.loadHomeData(companyId);
      orders.watchOrders(uid, companyId);
      final recentIds = await recentIdsFuture;
      if (recentIds.isNotEmpty) {
        await catalog.loadRecentlyViewedMaterials(companyId, recentIds);
      }
      if (mounted) {
        setState(() => _initialized = true);
        _loadHomeAiGreeting();
        context.read<AiContextService>().updateContext('home', {
          'screen': 'home dashboard',
        });
      }
    } finally {
      _loadingHome = false;
    }
  }

  Future<void> _refresh() async {
    final session = context.read<FieldSessionViewModel>();
    final catalog = context.read<FieldCatalogViewModel>();
    final companyId = session.companyId;
    if (companyId == null) return;

    final recentIds = await RecentlyViewedService.getRecentIds();
    await Future.wait([
      session.loadCompanyContext(),
      catalog.loadHomeData(companyId),
      if (recentIds.isNotEmpty)
        catalog.loadRecentlyViewedMaterials(companyId, recentIds)
      else
        catalog.loadRecentlyViewedMaterials(companyId, []),
    ]);
  }

  Future<void> _loadHomeAiGreeting() async {
    if (!mounted) return;

    final materials = context.read<FieldCatalogViewModel>().catalogMaterials;
    if (materials.isEmpty) return;

    final byCategory = <String, List<double>>{};
    for (final material in materials) {
      if (material.pricePerUnit <= 0) continue;
      byCategory
          .putIfAbsent(material.category, () => [])
          .add(material.pricePerUnit);
    }
    if (byCategory.isEmpty) return;

    final payload =
        byCategory.entries.map((entry) {
          final prices = entry.value;
          final minPrice = prices.reduce((a, b) => a < b ? a : b);
          final maxPrice = prices.reduce((a, b) => a > b ? a : b);
          final avgPrice = prices.reduce((a, b) => a + b) / prices.length;
          return {
            'category': entry.key,
            'minPrice': minPrice.round(),
            'maxPrice': maxPrice.round(),
            'avgPrice': avgPrice.round(),
            'listingCount': prices.length,
          };
        }).toList();

    try {
      final line = await context
          .read<GeminiService>()
          .getHomeMarketGreeting(payload, locale: 'en')
          .timeout(const Duration(seconds: 20));
      final trimmed = line.trim();
      if (!mounted || trimmed.isEmpty) return;
      final lower = trimmed.toLowerCase();
      if (lower.contains('temporarily unavailable') ||
          lower.contains('rate limit')) {
        return;
      }
      setState(() => _homeAiGreeting = _limitWords(trimmed, 10));
    } catch (_) {
      // Silent hide on failure or timeout.
    }
  }

  static String _limitWords(String text, int maxWords) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final list = words.toList();
    if (list.length <= maxWords) return text;
    return list.take(maxWords).join(' ');
  }

  void _openNotifications() {
    FieldShellScope.maybeOf(
      context,
    )?.switchTab(FieldShellScope.notificationsTabIndex);
  }

  void _openProfile() {
    FieldShellScope.maybeOf(
      context,
    )?.switchTab(FieldShellScope.profileTabIndex);
  }

  void _openSearch() {
    context.push(RouteNames.fieldSearch);
  }

  void _openCategory(String categoryName) {
    context.push(
      RouteNames.fieldCategory.replaceFirst(
        ':categoryName',
        Uri.encodeComponent(categoryName),
      ),
    );
  }

  void _openAllCategories() {
    context.push(RouteNames.fieldCategories);
  }

  void _openMarketplace() {
    context.push(RouteNames.fieldMarketplace);
  }

  void _openRfqs() {
    context.push(RouteNames.fieldRfqs);
  }

  void _openOrdersTab() {
    FieldShellScope.maybeOf(context)?.switchTab(FieldShellScope.ordersTabIndex);
  }

  void _openOrderDetail(OrderModel order) {
    context.push(
      RouteNames.fieldOrderDetail.replaceFirst(':orderId', order.orderId),
    );
  }

  Future<void> _openCompare(MaterialModel material) async {
    await context.read<RecentlyViewedService>().persistView(material.id);
    if (!mounted) return;
    final companyId = context.read<FieldSessionViewModel>().companyId;
    if (companyId != null) {
      final ids = await RecentlyViewedService.getRecentIds();
      if (!mounted) return;
      await context.read<FieldCatalogViewModel>().loadRecentlyViewedMaterials(
        companyId,
        ids,
      );
    }
    if (!mounted) return;
    context.push(
      RouteNames.fieldCompare.replaceFirst(
        ':materialId',
        Uri.encodeComponent(material.name),
      ),
    );
  }

  Future<void> _clearRecentlyViewed() async {
    await context.read<RecentlyViewedService>().wipeHistory();
    if (!mounted) return;
    final companyId = context.read<FieldSessionViewModel>().companyId;
    if (companyId != null) {
      await context.read<FieldCatalogViewModel>().loadRecentlyViewedMaterials(
        companyId,
        [],
      );
    }
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  bool _isInProgressOrder(OrderModel order) {
    if (FieldOrderStatus.isPending(order.status) ||
        FieldOrderStatus.isActive(order.status)) {
      return true;
    }
    return FieldOrderStatus.normalize(order.status) == 'delivered';
  }

  int _inProgressOrderCount(List<OrderModel> orders) =>
      orders.where(_isInProgressOrder).length;

  List<OrderModel> _inProgressOrders(List<OrderModel> orders) =>
      orders.where(_isInProgressOrder).take(3).toList();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<FieldSessionViewModel>();
    final catalog = context.watch<FieldCatalogViewModel>();
    final orders = context.watch<FieldOrdersViewModel>();
    final notifications = context.watch<FieldNotificationsViewModel>();

    final user = session.user;
    if (user == null) {
      return const FieldLoadingState(message: 'Loading your dashboard…');
    }

    if (!_initialized &&
        !_loadingHome &&
        session.companyId != null &&
        session.user?.uid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadHome());
    }

    final topPadding = MediaQuery.paddingOf(context).top;
    final categoryNames = catalog.uniqueCategories;
    final browseCategories = catalog.browseCategories;
    final inProgressCount = _inProgressOrderCount(orders.orders);
    final inProgressOrders = _inProgressOrders(orders.orders);
    final isMaterialsLoading =
        !_initialized && catalog.isLoading && catalog.recentMaterials.isEmpty;
    final recentlyViewed = catalog.recentlyViewedMaterials;

    return ColoredBox(
      color: FieldColors.screenBackground,
      child: Column(
        children: [
          _DarazStickyHeader(
            topPadding: topPadding,
            gradient: _navyGradient,
            unreadCount: notifications.unreadCount,
            userInitials: _initials(user.name),
            smartContextLine: _homeAiGreeting,
            onNotificationsTap: _openNotifications,
            onProfileTap: _openProfile,
            onSearchTap: _openSearch,
          ),
          Expanded(
            child: RefreshIndicator(
              color: FieldColors.primaryNavy,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: _CategoryQuickAccessRow(
                      categoryNames: categoryNames,
                      isLoading: catalog.isLoading && categoryNames.isEmpty,
                      onCategoryTap: _openCategory,
                      onSeeAllTap: _openAllCategories,
                      onRetry:
                          catalog.errorMessage != null
                              ? () {
                                final companyId = session.companyId;
                                if (companyId != null) {
                                  catalog.loadHomeData(companyId);
                                }
                              }
                              : null,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: FieldColors.screenBackground,
                            child: Icon(
                              Icons.request_quote_outlined,
                              color: FieldColors.primaryNavy,
                            ),
                          ),
                          title: const Text('Request a Bulk Quote'),
                          subtitle: const Text(
                            'Compare live bids from matching suppliers · Premium',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _openRfqs,
                        ),
                      ),
                    ),
                  ),
                  if (inProgressCount > 0)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _ActiveOrdersBanner(
                          count: inProgressCount,
                          onTap: _openOrdersTab,
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: _SectionHeaderRow(
                        title: 'New Materials',
                        actionLabel: 'See all →',
                        onAction: _openMarketplace,
                      ),
                    ),
                  ),
                  if (isMaterialsLoading)
                    const SliverToBoxAdapter(
                      child: _HorizontalMaterialSkeleton(
                        cardWidth: 150,
                        cardHeight: 210,
                      ),
                    )
                  else if (catalog.recentMaterials.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _SectionEmptyMessage(
                          message:
                              'No materials available yet from your suppliers',
                          onRetry:
                              catalog.errorMessage != null
                                  ? () {
                                    final companyId = session.companyId;
                                    if (companyId != null) {
                                      catalog.loadHomeData(companyId);
                                    }
                                  }
                                  : null,
                        ),
                      ),
                    )
                  else
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 220,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          itemCount: catalog.recentMaterials.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final material = catalog.recentMaterials[index];
                            return _NewMaterialCard(
                              material: material,
                              onCompare: () => _openCompare(material),
                            );
                          },
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: _SectionHeaderRow(
                        title: 'Browse by Category',
                        showAction: false,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _BrowseCategoryGrid(
                        categories: browseCategories,
                        isLoading:
                            catalog.isLoading && browseCategories.isEmpty,
                        materialCountFor: catalog.materialCountForCategory,
                        onCategoryTap: (name) => _openCategory(name),
                        onViewAll: _openAllCategories,
                        onRetry:
                            catalog.errorMessage != null
                                ? () {
                                  final companyId = session.companyId;
                                  if (companyId != null) {
                                    catalog.loadHomeData(companyId);
                                  }
                                }
                                : null,
                      ),
                    ),
                  ),
                  if (recentlyViewed.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                        child: _SectionHeaderRow(
                          title: 'Recently Viewed',
                          actionLabel: 'Clear',
                          onAction: _clearRecentlyViewed,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 220,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          itemCount: recentlyViewed.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final material = recentlyViewed[index];
                            return _CompactMaterialCard(
                              material: material,
                              width: 130,
                              onCompare: () => _openCompare(material),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: _SectionHeaderRow(
                        title: 'My Active Orders',
                        actionLabel: 'View all →',
                        onAction: _openOrdersTab,
                      ),
                    ),
                  ),
                  if (inProgressOrders.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _CalmOrdersEmptyState(),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      sliver: SliverList.separated(
                        itemCount: inProgressOrders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          return _OrderQuickTile(
                            order: inProgressOrders[index],
                            onTap:
                                () => _openOrderDetail(inProgressOrders[index]),
                          );
                        },
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Part 1: Sticky header ───────────────────────────────────────────────────

class _DarazStickyHeader extends StatelessWidget {
  final double topPadding;
  final LinearGradient gradient;
  final int unreadCount;
  final String userInitials;
  final String? smartContextLine;
  final VoidCallback onNotificationsTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSearchTap;

  const _DarazStickyHeader({
    required this.topPadding,
    required this.gradient,
    required this.unreadCount,
    required this.userInitials,
    this.smartContextLine,
    required this.onNotificationsTap,
    required this.onProfileTap,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: gradient),
      padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'RateBridge',
                style: FieldTypography.headlineMedium.copyWith(
                  color: FieldColors.accentAmber,
                  fontSize: 20,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onNotificationsTap,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Badge(
                    isLabelVisible: unreadCount > 0,
                    backgroundColor: FieldColors.statusDanger,
                    label: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: onProfileTap,
                customBorder: const CircleBorder(),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: FieldColors.accentAmber,
                  child: Text(
                    userInitials,
                    style: FieldTypography.labelSmall.copyWith(
                      color: FieldColors.primaryNavy,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSearchTap,
              borderRadius: BorderRadius.circular(10),
              child: Ink(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      size: 20,
                      color: FieldColors.textMuted.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Search cement, steel, bricks...',
                        style: FieldTypography.bodyMedium.copyWith(
                          color: FieldColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (smartContextLine != null && smartContextLine!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 11,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      smartContextLine!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'PlusJakartaSans',
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Part 2: Category quick access ───────────────────────────────────────────

class _CategoryQuickAccessRow extends StatelessWidget {
  final List<String> categoryNames;
  final bool isLoading;
  final ValueChanged<String> onCategoryTap;
  final VoidCallback onSeeAllTap;
  final VoidCallback? onRetry;

  const _CategoryQuickAccessRow({
    required this.categoryNames,
    required this.isLoading,
    required this.onCategoryTap,
    required this.onSeeAllTap,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FieldColors.screenBackground,
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading)
            const _CategoryChipSkeleton()
          else if (categoryNames.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SectionEmptyMessage(
                message: 'No categories available yet.',
                onRetry: onRetry,
              ),
            )
          else
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categoryNames.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  if (index == categoryNames.length) {
                    return _AllCategoriesChip(onTap: onSeeAllTap);
                  }
                  final name = categoryNames[index];
                  return _CategoryQuickChip(
                    name: name,
                    onTap: () => onCategoryTap(name),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryQuickChip extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _CategoryQuickChip({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: 72,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: FieldColors.primaryNavy.withValues(alpha: 0.2),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: FieldColors.primaryNavy.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                fieldMaterialCategoryIcon(name),
                size: 24,
                color: FieldColors.primaryNavy,
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FieldTypography.labelSmall.copyWith(
                    color: FieldColors.primaryNavy,
                    fontSize: 10,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllCategoriesChip extends StatelessWidget {
  final VoidCallback onTap;

  const _AllCategoriesChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          width: 72,
          height: 80,
          decoration: BoxDecoration(
            color: FieldColors.accentAmber,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              'All →',
              textAlign: TextAlign.center,
              style: FieldTypography.bodyMedium.copyWith(
                color: FieldColors.primaryNavy,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChipSkeleton extends StatelessWidget {
  const _CategoryChipSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder:
            (_, __) => Shimmer.fromColors(
              baseColor: FieldColors.borderSubtle,
              highlightColor: FieldColors.surfaceWhite,
              child: Container(
                width: 72,
                height: 80,
                decoration: BoxDecoration(
                  color: FieldColors.borderSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
      ),
    );
  }
}

// ─── Part 3: Active orders banner ────────────────────────────────────────────

class _ActiveOrdersBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _ActiveOrdersBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? 'active order' : 'active orders';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                decoration: BoxDecoration(
                  color: FieldColors.accentAmber.withValues(alpha: 0.12),
                  border: Border.all(
                    color: FieldColors.accentAmber.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📦 $count $label in progress',
                            style: FieldTypography.titleMedium.copyWith(
                              color: FieldColors.primaryNavy,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to track your orders',
                            style: FieldTypography.bodyMedium.copyWith(
                              color: FieldColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: FieldColors.primaryNavy.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 4, color: FieldColors.accentAmber),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared section chrome ───────────────────────────────────────────────────

class _SectionHeaderRow extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showAction;

  const _SectionHeaderRow({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.showAction = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: FieldTypography.titleMedium.copyWith(
            color: FieldColors.primaryNavy,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const Spacer(),
        if (showAction && actionLabel != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: FieldTypography.bodyMedium.copyWith(
                color: FieldColors.accentAmber,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionEmptyMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _SectionEmptyMessage({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: FieldColors.textMuted.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: FieldTypography.bodyMedium.copyWith(
              color: FieldColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: FieldColors.accentAmber,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}

// ─── Part 4 & 6: Material cards ──────────────────────────────────────────────

class _NewMaterialCard extends StatelessWidget {
  final MaterialModel material;
  final VoidCallback onCompare;

  const _NewMaterialCard({required this.material, required this.onCompare});

  @override
  Widget build(BuildContext context) {
    return _CompactMaterialCard(
      material: material,
      width: 150,
      onCompare: onCompare,
    );
  }
}

class _CompactMaterialCard extends StatelessWidget {
  final MaterialModel material;
  final double width;
  final VoidCallback onCompare;

  const _CompactMaterialCard({
    required this.material,
    required this.width,
    required this.onCompare,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 220,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FieldColors.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 76, child: _MaterialImageTop(material: material)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            material.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: FieldTypography.titleMedium.copyWith(
                              fontSize: 12,
                              height: 1.15,
                              color: FieldColors.primaryNavy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            material.supplierName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FieldTypography.bodyMedium.copyWith(
                              fontSize: 10,
                              color: FieldColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(
                            CurrencyFormatter.formatPKR(material.pricePerUnit),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FieldTypography.titleMedium.copyWith(
                              color: FieldColors.accentAmber,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Text(
                          '/${material.unit}',
                          style: FieldTypography.bodyMedium.copyWith(
                            fontSize: 10,
                            color: FieldColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 26,
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: onCompare,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FieldColors.primaryNavy,
                          side: BorderSide(
                            color: FieldColors.primaryNavy.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          padding: EdgeInsets.zero,
                          textStyle: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Compare'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialImageTop extends StatelessWidget {
  final MaterialModel material;

  const _MaterialImageTop({required this.material});

  @override
  Widget build(BuildContext context) {
    final url = material.profileImageUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _iconFallback(),
      );
    }
    return _iconFallback();
  }

  Widget _iconFallback() {
    return Container(
      color: FieldColors.accentAmber.withValues(alpha: 0.12),
      child: Center(
        child: Icon(
          fieldMaterialCategoryIcon(material.category),
          size: 32,
          color: FieldColors.primaryNavy,
        ),
      ),
    );
  }
}

class _HorizontalMaterialSkeleton extends StatelessWidget {
  final double cardWidth;
  final double cardHeight;

  const _HorizontalMaterialSkeleton({
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: cardHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder:
            (_, __) => Shimmer.fromColors(
              baseColor: FieldColors.borderSubtle,
              highlightColor: FieldColors.surfaceWhite,
              child: Container(
                width: cardWidth,
                decoration: BoxDecoration(
                  color: FieldColors.borderSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
      ),
    );
  }
}

// ─── Part 5: Browse by category grid ─────────────────────────────────────────

class _BrowseCategoryGrid extends StatelessWidget {
  final List<CategoryModel> categories;
  final bool isLoading;
  final int Function(String) materialCountFor;
  final ValueChanged<String> onCategoryTap;
  final VoidCallback onViewAll;
  final VoidCallback? onRetry;

  const _BrowseCategoryGrid({
    required this.categories,
    required this.isLoading,
    required this.materialCountFor,
    required this.onCategoryTap,
    required this.onViewAll,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _BrowseCategorySkeleton();
    }

    if (categories.isEmpty) {
      return _SectionEmptyMessage(
        message: 'No categories to browse yet.',
        onRetry: onRetry,
      );
    }

    final visible = categories.take(6).toList();
    final hasMore = categories.length > 6;

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
          ),
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final category = visible[index];
            final count = materialCountFor(category.name);
            return _BrowseCategoryCard(
              name: category.name,
              materialCount: count,
              onTap: () => onCategoryTap(category.name),
            );
          },
        ),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onViewAll,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: FieldColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'View all categories',
                        style: FieldTypography.bodyMedium.copyWith(
                          color: FieldColors.primaryNavy,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: FieldColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _BrowseCategoryCard extends StatelessWidget {
  final String name;
  final int materialCount;
  final VoidCallback onTap;

  const _BrowseCategoryCard({
    required this.name,
    required this.materialCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FieldColors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        fieldMaterialCategoryIcon(name),
                        size: 28,
                        color: FieldColors.primaryNavy,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: FieldTypography.titleMedium.copyWith(
                            color: FieldColors.primaryNavy,
                            fontSize: 14,
                            height: 1.2,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$materialCount',
                            style: FieldTypography.labelSmall.copyWith(
                              color: FieldColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: FieldColors.textMuted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                height: 2,
                decoration: BoxDecoration(
                  color: FieldColors.accentAmber,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrowseCategorySkeleton extends StatelessWidget {
  const _BrowseCategorySkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemCount: 4,
      itemBuilder:
          (_, __) => Shimmer.fromColors(
            baseColor: FieldColors.borderSubtle,
            highlightColor: FieldColors.surfaceWhite,
            child: Container(
              decoration: BoxDecoration(
                color: FieldColors.borderSubtle,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
    );
  }
}

// ─── Part 7: Active orders quick view ────────────────────────────────────────

class _OrderQuickTile extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const _OrderQuickTile({required this.order, required this.onTap});

  Color _dotColor(String status) {
    if (FieldOrderStatus.isPending(status)) return FieldColors.accentAmber;
    if (FieldOrderStatus.isActive(status)) return FieldColors.primaryNavy;
    if (FieldOrderStatus.normalize(status) == 'delivered') {
      return FieldColors.statusPurple;
    }
    return FieldColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final colors = FieldOrderStatus.colorsFor(order.status);
    final label = FieldOrderStatus.displayLabel(order.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FieldColors.borderSubtle),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _dotColor(order.status),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.materialName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FieldTypography.titleMedium.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.supplierName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FieldTypography.bodyMedium.copyWith(
                        fontSize: 12,
                        color: FieldColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: FieldTypography.labelSmall.copyWith(
                    color: colors.fg,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: FieldColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalmOrdersEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FieldColors.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 20,
            color: FieldColors.textMuted.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Text(
            'No active orders',
            style: FieldTypography.bodyMedium.copyWith(
              color: FieldColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
