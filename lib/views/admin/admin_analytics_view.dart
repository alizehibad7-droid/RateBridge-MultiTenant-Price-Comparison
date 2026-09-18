import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../theme/admin_theme.dart';
import '../../widgets/admin/admin_widgets.dart';
import '../../models/user_model.dart';
import '../../models/order_model.dart';
import '../../models/company_model.dart';
import '../../models/rating_model.dart';

class AdminAnalyticsView extends StatefulWidget {
  const AdminAnalyticsView({super.key});

  @override
  State<AdminAnalyticsView> createState() => _AdminAnalyticsViewState();
}

class _AdminAnalyticsViewState extends State<AdminAnalyticsView> {
  String _ceoMetric = 'Orders';
  String _supplierMetric = 'Orders';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminViewModel>().loadAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final adminVM = context.watch<AdminViewModel>();
    
    // Determine if this is a "hard" loading state (no data at all)
    final bool isHardLoading = adminVM.isLoading && 
                               adminVM.ceoPerformance.isEmpty && 
                               adminVM.supplierPerformance.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildTopHeader(adminVM),
          Expanded(
            child: adminVM.analyticsError != null
                ? _buildErrorState(adminVM.analyticsError!)
                : isHardLoading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : Stack(
                        children: [
                          _buildBody(adminVM),
                          if (adminVM.isLoading)
                            Positioned(
                              top: 0, left: 0, right: 0,
                              child: LinearProgressIndicator(
                                minHeight: 3,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(AdminColors.amber.withValues(alpha: 0.8)),
                              ),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.analytics_outlined, size: 64, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          Text('Analytics temporarily unavailable', style: AdminTheme.titleStyle(size: 18)),
          const SizedBox(height: 8),
          Text(error, style: AdminTheme.mutedStyle()),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.read<AdminViewModel>().loadAnalytics(),
            child: const Text('Refresh Insights'),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(AdminViewModel adminVM) {
    final mode = adminVM.analyticsMode;

    return Container(
      height: 72,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (mode != AnalyticsViewMode.overall) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => adminVM.setAnalyticsMode(AnalyticsViewMode.overall),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                padding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              mode == AnalyticsViewMode.ceoDetail ? 'CEO Intelligence' : 'Supplier Metrics',
              style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AdminColors.navy),
            ),
          ] else ...[
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enterprise Intelligence',
                  style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900, color: AdminColors.navy, letterSpacing: -0.5),
                ),
                Text('Real-time ecosystem monitoring', style: AdminTheme.mutedStyle(size: 11)),
              ],
            ),
            const SizedBox(width: 40),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AdminColors.navy),
                    decoration: InputDecoration(
                      hintText: 'Search partners...',
                      hintStyle: AdminTheme.mutedStyle(size: 13),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AdminColors.textGrey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ),
          ],

          const Spacer(),

          _buildHeaderFilter(
            value: adminVM.timeRange,
            icon: Icons.calendar_today_rounded,
            items: const ['7 Days', '30 Days', '3 Months', 'All Time'],
            onChanged: (val) { if (val != null) adminVM.setTimeRange(val); },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderFilter({String? value, String? hint, required IconData icon, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AdminColors.textGrey),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : null,
              hint: hint != null ? Text(hint, style: AdminTheme.mutedStyle(size: 12, weight: FontWeight.w600)) : null,
              icon: const Icon(Icons.expand_more_rounded, size: 18),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: AdminTheme.bodyStyle(size: 12, weight: FontWeight.w600)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(AdminViewModel adminVM) {
    switch (adminVM.analyticsMode) {
      case AnalyticsViewMode.overall:
        return _OverallAnalyticsSection(
          onCEOClick: (uid) => adminVM.setAnalyticsMode(AnalyticsViewMode.ceoDetail, id: uid),
          onSupplierClick: (uid) => adminVM.setAnalyticsMode(AnalyticsViewMode.supplierDetail, id: uid),
          ceoMetric: _ceoMetric,
          onCEOMetricChange: (val) => setState(() => _ceoMetric = val),
          supplierMetric: _supplierMetric,
          onSupplierMetricChange: (val) => setState(() => _supplierMetric = val),
          searchQuery: _searchQuery,
        );
      case AnalyticsViewMode.ceoDetail:
        return _CEODetailSection(key: ValueKey('ceo_${adminVM.selectedPartnerId}'), ceoUid: adminVM.selectedPartnerId);
      case AnalyticsViewMode.supplierDetail:
        return _SupplierDetailSection(key: ValueKey('sup_${adminVM.selectedPartnerId}'), supplierUid: adminVM.selectedPartnerId);
    }
  }
}

class _OverallAnalyticsSection extends StatelessWidget {
  final Function(String) onCEOClick;
  final Function(String) onSupplierClick;
  final String ceoMetric;
  final Function(String) onCEOMetricChange;
  final String supplierMetric;
  final Function(String) onSupplierMetricChange;
  final String searchQuery;

  const _OverallAnalyticsSection({
    required this.onCEOClick,
    required this.onSupplierClick,
    required this.ceoMetric,
    required this.onCEOMetricChange,
    required this.supplierMetric,
    required this.onSupplierMetricChange,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final adminVM = context.watch<AdminViewModel>();
    final stats = adminVM.stats;

    final filteredCEO = adminVM.ceoPerformance.where((e) => 
      e.companyName.toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();

    final filteredSuppliers = adminVM.supplierPerformance.where((e) => 
      e.businessName.toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();

    return RefreshIndicator(
      onRefresh: () => adminVM.loadAnalytics(),
      color: AdminColors.navy,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricsGrid(context, stats, adminVM.timeRange),
            const SizedBox(height: 32),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1100;
                return Column(
                  children: [
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildComparisonCard(
                            context: context,
                            title: 'CEO Matrix',
                            subtitle: 'Enterprise throughput analysis (${adminVM.timeRange})',
                            metric: ceoMetric,
                            options: const ['Orders', 'Completed', 'Field Users'],
                            onMetricChange: onCEOMetricChange,
                            chart: _ModernBarChart(
                              labels: filteredCEO.map((e) => e.companyName).toList(),
                              values: filteredCEO.map((e) => _getCeoValue(e)).toList(),
                              color: AdminColors.navy,
                              onClick: (idx) => onCEOClick(filteredCEO[idx].ceoUid),
                            ),
                            footer: _RankingList(
                              title: 'ALL PARTNERS',
                              items: filteredCEO.map((e) => _RankData(
                                title: e.companyName,
                                subtitle: '${e.totalOrders} total orders',
                                value: '${e.completionRate.toInt()}%',
                                label: 'Efficiency',
                                color: AdminColors.green,
                                onClick: () => onCEOClick(e.ceoUid),
                              )).toList(),
                            ),
                          )),
                          const SizedBox(width: 24),
                          Expanded(child: _buildComparisonCard(
                            context: context,
                            title: 'Supplier Index',
                            subtitle: 'Vendor reliability benchmarks (${adminVM.timeRange})',
                            metric: supplierMetric,
                            options: const ['Orders', 'Completed', 'Rating', 'Reviews'],
                            onMetricChange: onSupplierMetricChange,
                            chart: _ModernBarChart(
                              labels: filteredSuppliers.map((e) => e.businessName).toList(),
                              values: filteredSuppliers.map((e) => _getSupplierValue(e)).toList(),
                              color: AdminColors.amber,
                              onClick: (idx) => onSupplierClick(filteredSuppliers[idx].supplierUid),
                            ),
                            footer: _RankingList(
                              title: 'ALL SUPPLIERS',
                              items: filteredSuppliers.map((e) => _RankData(
                                title: e.businessName,
                                subtitle: '${e.totalReviews} verified reviews',
                                value: e.averageRating.toStringAsFixed(1),
                                label: 'Score',
                                color: AdminColors.amber,
                                onClick: () => onSupplierClick(e.supplierUid),
                              )).toList(),
                            ),
                          )),
                        ],
                      )
                    else ...[
                      _buildComparisonCard(
                        context: context,
                        title: 'CEO Performance Matrix',
                        subtitle: 'Operational efficiency by tenant (${adminVM.timeRange})',
                        metric: ceoMetric,
                        options: const ['Orders', 'Completed', 'Field Users'],
                        onMetricChange: onCEOMetricChange,
                        chart: _ModernBarChart(
                          labels: filteredCEO.map((e) => e.companyName).toList(),
                          values: filteredCEO.map((e) => _getCeoValue(e)).toList(),
                          color: AdminColors.navy,
                          onClick: (idx) => onCEOClick(filteredCEO[idx].ceoUid),
                        ),
                        footer: _RankingList(
                          title: 'ALL PARTNERS',
                          items: filteredCEO.map((e) => _RankData(
                            title: e.companyName,
                            subtitle: '${e.totalOrders} total orders',
                            value: '${e.completionRate.toInt()}%',
                            label: 'Efficiency',
                            color: AdminColors.green,
                            onClick: () => onCEOClick(e.ceoUid),
                          )).toList(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildComparisonCard(
                        context: context,
                        title: 'Supplier Benchmarks',
                        subtitle: 'Quality and volume indexes (${adminVM.timeRange})',
                        metric: supplierMetric,
                        options: const ['Orders', 'Completed', 'Rating', 'Reviews'],
                        onMetricChange: onSupplierMetricChange,
                        chart: _ModernBarChart(
                          labels: filteredSuppliers.map((e) => e.businessName).toList(),
                          values: filteredSuppliers.map((e) => _getSupplierValue(e)).toList(),
                          color: AdminColors.amber,
                          onClick: (idx) => onSupplierClick(filteredSuppliers[idx].supplierUid),
                        ),
                        footer: _RankingList(
                          title: 'ALL SUPPLIERS',
                          items: filteredSuppliers.map((e) => _RankData(
                            title: e.businessName,
                            subtitle: '${e.totalReviews} verified reviews',
                            value: e.averageRating.toStringAsFixed(1),
                            label: 'Score',
                            color: AdminColors.amber,
                            onClick: () => onSupplierClick(e.supplierUid),
                          )).toList(),
                        ),
                      ),
                    ]
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  double _getCeoValue(CEOPerformanceData d) {
    switch (ceoMetric) {
      case 'Orders': return d.totalOrders.toDouble();
      case 'Completed': return d.completedOrders.toDouble();
      case 'Field Users': return d.fieldUserCount.toDouble();
      default: return 0;
    }
  }

  double _getSupplierValue(SupplierPerformanceData d) {
    switch (supplierMetric) {
      case 'Orders': return d.totalOrders.toDouble();
      case 'Completed': return d.completedOrders.toDouble();
      case 'Rating': return d.averageRating;
      case 'Reviews': return d.totalReviews.toDouble();
      default: return 0;
    }
  }

  Widget _buildMetricsGrid(BuildContext context, AdminStats stats, String range) {
    final width = MediaQuery.of(context).size.width;
    int cols = width > 1400 ? 4 : (width > 900 ? 2 : 1);
    double ratio = width > 600 ? 2.5 : 3.0;

    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: ratio,
      children: [
        _ExecutiveStatCard(label: 'Total Tenants', value: '${stats.totalCEOs}', icon: Icons.business_center_rounded, color: AdminColors.navy),
        _ExecutiveStatCard(label: 'Net Volume ($range)', value: '${stats.totalOrders}', icon: Icons.analytics_rounded, color: AdminColors.green),
        _ExecutiveStatCard(label: 'Active Force', value: '${stats.totalFieldUsers}', icon: Icons.engineering_rounded, color: AdminColors.amber),
        _ExecutiveStatCard(label: 'Market Health ($range)', value: '${stats.avgSupplierRating.toStringAsFixed(1)} ★', icon: Icons.verified_rounded, color: AdminColors.purple),
      ],
    );
  }

  Widget _buildComparisonCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String metric,
    required List<String> options,
    required Function(String) onMetricChange,
    required Widget chart,
    required Widget footer,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AdminColors.navy)),
                      Text(subtitle, style: AdminTheme.mutedStyle(size: 12)),
                    ],
                  ),
                ),
                _MetricSelector(value: metric, options: options, onChanged: onMetricChange),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 24),
          SizedBox(height: 280, child: chart),
          const SizedBox(height: 24),
          const Divider(height: 1),
          footer,
        ],
      ),
    );
  }
}

class _ExecutiveStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ExecutiveStatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: AdminTheme.mutedStyle(size: 11, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AdminColors.navy,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernBarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final Color color;
  final Function(int) onClick;

  const _ModernBarChart({required this.labels, required this.values, required this.color, required this.onClick});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const Center(child: Text('No visualization data'));

    final double maxVal = values.reduce((a, b) => a > b ? a : b);
    final double maxY = maxVal == 0 ? 100 : maxVal * 1.3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AdminColors.navy,
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${labels[groupIndex]}\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                children: [
                  TextSpan(text: rod.toY.toStringAsFixed(rod.toY < 10 && rod.toY > 0 ? 1 : 0), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                ],
              ),
            ),
            touchCallback: (event, response) {
              if (event is FlTapUpEvent && response?.spot != null) onClick(response!.spot!.touchedBarGroupIndex);
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= labels.length) return const SizedBox();
                  final name = labels[value.toInt()];
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(name.length > 6 ? '${name.substring(0, 4)}..' : name, style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8))),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8))),
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          barGroups: values.asMap().entries.map((e) => BarChartGroupData(
            x: e.key,
            barRods: [BarChartRodData(
              toY: e.value,
              gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)], begin: Alignment.bottomCenter, end: Alignment.topCenter),
              width: 22,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: const Color(0xFFF8FAFC)),
            )],
          )).toList(),
        ),
      ),
    );
  }
}

class _RankingList extends StatelessWidget {
  final String title;
  final List<_RankData> items;
  const _RankingList({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title.toUpperCase(), style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8), letterSpacing: 1.0)),
              const Icon(Icons.star_rounded, size: 14, color: AdminColors.amber),
            ],
          ),
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('No results matching criteria', style: TextStyle(fontSize: 12, color: Colors.grey))),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                onTap: item.onClick,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                leading: Text('${index + 1}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AdminColors.textGrey, fontSize: 12)),
                title: Text(item.title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: AdminColors.navy, fontSize: 13)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.value, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: item.color, fontSize: 14)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFCBD5E1)),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _RankData {
  final String title, subtitle, value, label;
  final Color color;
  final VoidCallback onClick;
  _RankData({required this.title, required this.subtitle, required this.value, required this.label, required this.color, required this.onClick});
}

class _MetricSelector extends StatelessWidget {
  final String value;
  final List<String> options;
  final Function(String) onChanged;

  const _MetricSelector({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.unfold_more_rounded, size: 14, color: AdminColors.navy),
          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w800, color: AdminColors.navy),
          items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (val) { if (val != null) onChanged(val); },
        ),
      ),
    );
  }
}

class _CEODetailSection extends StatefulWidget {
  final String ceoUid;
  const _CEODetailSection({required this.ceoUid, super.key});

  @override
  State<_CEODetailSection> createState() => _CEODetailSectionState();
}

class _CEODetailSectionState extends State<_CEODetailSection> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final adminVM = context.read<AdminViewModel>();
    _tabController = TabController(
      length: 4, 
      vsync: this, 
      initialIndex: adminVM.ceoDetailTabIndex
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        adminVM.setCEODetailTab(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminVM = context.watch<AdminViewModel>();
    final perf = adminVM.ceoPerformance.firstWhere((c) => c.ceoUid == widget.ceoUid, orElse: () => CEOPerformanceData(ceoUid: widget.ceoUid, companyId: '', companyName: 'Unknown'));
    final company = adminVM.companiesList.firstWhere((c) => c.ceoUid == widget.ceoUid || c.id == perf.companyId, orElse: () => CompanyModel(id: '', name: perf.companyName, registrationNumber: '', address: '', status: 'active', createdAt: DateTime.now()));

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AdminColors.navy,
            unselectedLabelColor: AdminColors.textGrey,
            indicatorColor: AdminColors.green,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
            tabs: const [
              Tab(text: 'Operational KPI'),
              Tab(text: 'Workforce'),
              Tab(text: 'Transactions'),
              Tab(text: 'History'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverview(company, perf, adminVM.timeRange),
              _buildFieldUsers(adminVM, company),
              _buildOrders(adminVM, company),
              _buildPerformanceGraph(adminVM, company),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverview(CompanyModel company, CEOPerformanceData stats, String range) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminCard(
            title: 'Organization Identity',
            child: LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              return isNarrow ? Column(
                children: [
                  _DetailRow(label: 'CEO Principal', value: stats.companyName),
                  _DetailRow(label: 'Legal Entity', value: company.name),
                  _DetailRow(label: 'Verification Status', value: company.status.toUpperCase(), valueColor: AdminColors.green),
                  _DetailRow(label: 'Service Plan', value: (company.plan ?? 'Pro').toUpperCase()),
                  _DetailRow(label: 'Onboarding', value: DateFormat('MMM d, yyyy').format(company.createdAt)),
                ],
              ) : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _DetailRow(label: 'CEO Principal', value: stats.companyName),
                        _DetailRow(label: 'Legal Entity', value: company.name),
                        _DetailRow(label: 'Verification Status', value: company.status.toUpperCase(), valueColor: AdminColors.green),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                  Expanded(
                    child: Column(
                      children: [
                        _DetailRow(label: 'Service Plan', value: (company.plan ?? 'Pro').toUpperCase()),
                        _DetailRow(label: 'Onboarding', value: DateFormat('MMM d, yyyy').format(company.createdAt)),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 24),
          Text('Activity Overview ($range)', style: AdminTheme.titleStyle(size: 14)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
                children: [
                  _MetricTile(label: 'Total POs', value: '${stats.totalOrders}', icon: Icons.shopping_bag_rounded, color: AdminColors.navy),
                  _MetricTile(label: 'Fulfilled', value: '${stats.completedOrders}', icon: Icons.check_circle_rounded, color: AdminColors.green),
                  _MetricTile(label: 'In-Flight', value: '${stats.activeOrders}', icon: Icons.pending_rounded, color: AdminColors.amber),
                  _MetricTile(label: 'Operations', value: '${stats.fieldUserCount}', icon: Icons.people_rounded, color: AdminColors.purple),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFieldUsers(AdminViewModel vm, CompanyModel company) {
    final users = vm.allUsers.where((u) => u.companyId == company.id && u.role == 'field_user').toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AdminCard(
        title: 'Workforce Tracking',
        padding: EdgeInsets.zero,
        child: users.isEmpty
            ? const Padding(padding: EdgeInsets.all(48), child: Center(child: Text('No operational staff records')))
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AdminColors.navy, fontSize: 12),
                  columns: const [
                    DataColumn(label: Text('Staff Member')),
                    DataColumn(label: Text('ID Reference')),
                    DataColumn(label: Text('Activity')),
                    DataColumn(label: Text('Onboarded')),
                  ],
                  rows: users.map((u) => DataRow(cells: [
                    DataCell(Text(u.name, style: AdminTheme.bodyStyle(weight: FontWeight.w700))),
                    DataCell(Text(u.uid.substring(0, 8), style: GoogleFonts.robotoMono(fontSize: 11))),
                    DataCell(StatusChip(status: u.status ?? 'active')),
                    DataCell(Text(DateFormat('MMM d, yyyy').format(u.createdAt))),
                  ])).toList(),
                ),
              ),
      ),
    );
  }

  Widget _buildOrders(AdminViewModel vm, CompanyModel company) {
    return FutureBuilder<List<OrderModel>>(
      future: vm.getCompanyOrders(company.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final orders = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AdminCard(
            title: 'Transaction Audit Trail (${vm.timeRange})',
            padding: EdgeInsets.zero,
            child: orders.isEmpty
                ? const Padding(padding: EdgeInsets.all(48), child: Center(child: Text('No transactions recorded in this period')))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingTextStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AdminColors.navy, fontSize: 12),
                      columns: const [
                        DataColumn(label: Text('Ref #')),
                        DataColumn(label: Text('SKU / Material')),
                        DataColumn(label: Text('Vendor')),
                        DataColumn(label: Text('Total (PKR)')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: orders.map((o) => DataRow(cells: [
                        DataCell(Text(o.orderId.substring(0, 8), style: GoogleFonts.robotoMono(fontSize: 11))),
                        DataCell(Text(o.materialName)),
                        DataCell(Text(o.supplierName)),
                        DataCell(Text(NumberFormat.currency(symbol: '', decimalDigits: 0).format(o.totalAmount))),
                        DataCell(StatusChip(status: o.status)),
                      ])).toList(),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildPerformanceGraph(AdminViewModel vm, CompanyModel company) {
    return FutureBuilder<List<OrderModel>>(
      future: vm.getCompanyOrders(company.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final orders = snapshot.data!;
        final trend = vm.getHistoricalOrderTrend(orders);
        final List<FlSpot> spots = [];
        
        if (trend.isNotEmpty) {
          final sortedDates = trend.keys.toList()..sort();
          for (var date in sortedDates) {
            spots.add(FlSpot(date.millisecondsSinceEpoch.toDouble(), trend[date]!.toDouble()));
          }
        }
        
        double minX = spots.isEmpty ? 0 : spots.first.x;
        double maxX = spots.isEmpty ? 0 : spots.last.x;
        double range = maxX - minX;
        double interval = range > (86400000 * 14) ? 86400000 * 7 : 86400000;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AdminCard(
            title: 'Growth Analysis (${vm.timeRange})',
            child: SizedBox(
              height: 400,
              child: spots.isEmpty
                ? const Center(child: Text('Insufficient historical data for trend analysis'))
                : LineChart(LineChartData(
                    minX: minX, maxX: maxX, minY: 0,
                    gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1.5)),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => AdminColors.navy,
                        getTooltipItems: (touchedSpots) => touchedSpots.map((s) => LineTooltipItem('${DateFormat('MMM d').format(DateTime.fromMillisecondsSinceEpoch(s.x.toInt()))}\n${s.y.toInt()} Orders', const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))).toList(),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true, 
                          interval: interval, 
                          getTitlesWidget: (val, meta) => Padding(padding: const EdgeInsets.only(top: 12), child: Text(DateFormat('MMM d').format(DateTime.fromMillisecondsSinceEpoch(val.toInt())), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))))
                        )
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineBarsData: [LineChartBarData(
                      spots: spots, 
                      isCurved: true, 
                      color: AdminColors.green, 
                      barWidth: 4, 
                      dotData: const FlDotData(show: true), 
                      belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [AdminColors.green.withValues(alpha: 0.2), AdminColors.green.withValues(alpha: 0)], begin: Alignment.topCenter, end: Alignment.bottomCenter))
                    )]
                  )),
            ),
          ),
        );
      },
    );
  }
}

class _SupplierDetailSection extends StatefulWidget {
  final String supplierUid;
  const _SupplierDetailSection({required this.supplierUid, super.key});

  @override
  State<_SupplierDetailSection> createState() => _SupplierDetailSectionState();
}

class _SupplierDetailSectionState extends State<_SupplierDetailSection> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _performanceMetric = 'Orders';

  @override
  void initState() {
    super.initState();
    final adminVM = context.read<AdminViewModel>();
    _tabController = TabController(
      length: 4, 
      vsync: this,
      initialIndex: adminVM.supplierDetailTabIndex
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        adminVM.setSupplierDetailTab(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminVM = context.watch<AdminViewModel>();
    final perf = adminVM.supplierPerformance.firstWhere((s) => s.supplierUid == widget.supplierUid, orElse: () => SupplierPerformanceData(supplierUid: widget.supplierUid, businessName: 'Unknown'));
    final user = adminVM.allUsers.firstWhere((u) => u.uid == widget.supplierUid, orElse: () => UserModel(uid: widget.supplierUid, email: '', name: perf.businessName, role: 'Supplier', companyId: '', phone: '', city: '', createdAt: DateTime.now()));

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AdminColors.navy,
            unselectedLabelColor: AdminColors.textGrey,
            indicatorColor: AdminColors.amber,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13),
            tabs: const [Tab(text: 'Market Identity'), Tab(text: 'Supply Logs'), Tab(text: 'Sentiment'), Tab(text: 'KPI Mapping')],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverview(user, perf, adminVM.timeRange),
              _buildOrders(adminVM, user),
              _buildReviews(adminVM, user),
              _buildPerformanceGraph(adminVM, user),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverview(UserModel user, SupplierPerformanceData stats, String range) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          AdminCard(
            title: 'Market Identity',
            child: LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 600;
              return isNarrow ? Column(
                children: [
                  _DetailRow(label: 'Trade Name', value: user.name),
                  _DetailRow(label: 'Network ID', value: user.uid.substring(0, 12).toUpperCase()),
                  _DetailRow(label: 'Compliance', value: 'VERIFIED', valueColor: AdminColors.green),
                  _DetailRow(label: 'Location', value: user.city),
                  _DetailRow(label: 'Tenure', value: DateFormat('MMM yyyy').format(user.createdAt)),
                  _DetailRow(label: 'Primary Contact', value: user.email),
                ],
              ) : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _DetailRow(label: 'Trade Name', value: user.name),
                        _DetailRow(label: 'Network ID', value: user.uid.substring(0, 12).toUpperCase()),
                        _DetailRow(label: 'Compliance', value: 'VERIFIED', valueColor: AdminColors.green),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                  Expanded(
                    child: Column(
                      children: [
                        _DetailRow(label: 'Location', value: user.city),
                        _DetailRow(label: 'Tenure', value: DateFormat('MMM yyyy').format(user.createdAt)),
                        _DetailRow(label: 'Primary Contact', value: user.email),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 24),
          Align(alignment: Alignment.centerLeft, child: Text('Supply Metrics ($range)', style: AdminTheme.titleStyle(size: 14))),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final cols = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 1);
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
                children: [
                  _MetricTile(label: 'Supply Capacity', value: '${stats.totalOrders}', icon: Icons.local_shipping_rounded, color: AdminColors.navy),
                  _MetricTile(label: 'Success Delta', value: '${stats.completedOrders}', icon: Icons.assignment_turned_in_rounded, color: AdminColors.green),
                  _MetricTile(label: 'Market Score', value: stats.averageRating.toStringAsFixed(1), icon: Icons.star_rounded, color: AdminColors.amber),
                  _MetricTile(label: 'Public Sentiment', value: '${stats.totalReviews}', icon: Icons.rate_review_rounded, color: AdminColors.purple),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrders(AdminViewModel vm, UserModel user) {
    return FutureBuilder<List<OrderModel>>(
      future: vm.getSupplierOrders(user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final orders = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AdminCard(
            title: 'Supply logs (${vm.timeRange})',
            padding: EdgeInsets.zero,
            child: orders.isEmpty
                ? const Padding(padding: EdgeInsets.all(48), child: Center(child: Text('No supply logs found for this period')))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingTextStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: AdminColors.navy, fontSize: 12),
                      columns: const [
                        DataColumn(label: Text('PO Reference')),
                        DataColumn(label: Text('Material')),
                        DataColumn(label: Text('Requester')),
                        DataColumn(label: Text('Value (PKR)')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: orders.map((o) => DataRow(cells: [
                        DataCell(Text(o.orderId.substring(0, 8), style: GoogleFonts.robotoMono(fontSize: 11))),
                        DataCell(Text(o.materialName)),
                        DataCell(Text(o.fieldUserName)),
                        DataCell(Text(NumberFormat.currency(symbol: '', decimalDigits: 0).format(o.totalAmount))),
                        DataCell(StatusChip(status: o.status)),
                      ])).toList(),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildReviews(AdminViewModel vm, UserModel user) {
    return FutureBuilder<List<RatingModel>>(
      future: vm.getSupplierRatings(user.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final reviews = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AdminCard(
            title: 'Sentiment Logs (${vm.timeRange})',
            padding: EdgeInsets.zero,
            child: reviews.isEmpty
                ? const Padding(padding: EdgeInsets.all(48), child: Center(child: Text('No sentiment data collected for this period')))
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reviews.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final r = reviews[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: CircleAvatar(backgroundColor: const Color(0xFFF1F5F9), child: Text(r.userName[0], style: const TextStyle(fontWeight: FontWeight.w900, color: AdminColors.navy))),
                        title: Row(
                          children: [
                            Text(r.userName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13)),
                            const Spacer(),
                            Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, size: 14, color: i < r.rating ? AdminColors.amber : const Color(0xFFE2E8F0)))),
                          ],
                        ),
                        subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text(r.comment, style: AdminTheme.bodyStyle(size: 12, color: const Color(0xFF475569)))),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _buildPerformanceGraph(AdminViewModel vm, UserModel user) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([vm.getSupplierOrders(user.uid), vm.getSupplierRatings(user.uid)]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final orders = snapshot.data![0] as List<OrderModel>;
        final ratings = snapshot.data![1] as List<RatingModel>;
        final List<FlSpot> spots = [];
        
        if (_performanceMetric == 'Orders') {
          final trend = vm.getHistoricalOrderTrend(orders);
          final sortedDates = trend.keys.toList()..sort();
          for (var date in sortedDates) {
            spots.add(FlSpot(date.millisecondsSinceEpoch.toDouble(), trend[date]!.toDouble()));
          }
        } else {
          for (var r in ratings) {
            spots.add(FlSpot(r.createdAt.millisecondsSinceEpoch.toDouble(), r.rating.toDouble()));
          }
          spots.sort((a, b) => a.x.compareTo(b.x));
        }
        
        double minX = spots.isEmpty ? 0 : spots.first.x;
        double maxX = spots.isEmpty ? 0 : spots.last.x;
        double range = maxX - minX;
        double interval = range > (86400000 * 14) ? 86400000 * 7 : 86400000;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AdminCard(
            title: 'KPI Trend Mapping (${vm.timeRange})',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetricSelector(value: _performanceMetric, options: const ['Orders', 'Rating'], onChanged: (v) => setState(() => _performanceMetric = v)),
                const SizedBox(height: 24),
                SizedBox(
                  height: 400,
                  child: spots.isEmpty
                    ? const Center(child: Text('Insufficient historical throughput for mapping in this period'))
                    : LineChart(LineChartData(
                        minX: minX, maxX: maxX, minY: 0, 
                        maxY: _performanceMetric == 'Rating' ? 5.5 : null,
                        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: const Color(0xFFF1F5F9), strokeWidth: 1.5)),
                        borderData: FlBorderData(show: false),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (_) => AdminColors.navy,
                            getTooltipItems: (touchedSpots) => touchedSpots.map((s) => LineTooltipItem(
                              '${DateFormat('MMM d').format(DateTime.fromMillisecondsSinceEpoch(s.x.toInt()))}\n${_performanceMetric == 'Rating' ? s.y.toStringAsFixed(1) : s.y.toInt()} ${_performanceMetric}',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                            )).toList(),
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 45)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true, 
                              interval: interval, 
                              getTitlesWidget: (val, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(DateFormat('MMM d').format(DateTime.fromMillisecondsSinceEpoch(val.toInt())), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)))
                                );
                              }
                            )
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        lineBarsData: [LineChartBarData(
                          spots: spots, 
                          isCurved: true, 
                          color: AdminColors.amber, 
                          barWidth: 5, 
                          dotData: const FlDotData(show: true), 
                          belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [AdminColors.amber.withValues(alpha: 0.2), AdminColors.amber.withValues(alpha: 0)], begin: Alignment.topCenter, end: Alignment.bottomCenter))
                        )]
                      )),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: AdminColors.textGrey, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w900, color: AdminColors.navy, letterSpacing: -0.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _DetailRow({required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          Text(value, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: valueColor ?? AdminColors.navy, fontSize: 13)),
        ],
      ),
    );
  }
}
