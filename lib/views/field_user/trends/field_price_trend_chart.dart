import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/price_history_model.dart';
import '../../../theme/field_theme.dart';

class FieldPriceTrendChart extends StatelessWidget {
  final List<PriceHistoryModel> points;

  const FieldPriceTrendChart({
    super.key,
    required this.points,
  });

  static const _lineColor = FieldColors.accentAmber;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();

    final prices = points.map((p) => p.price).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final chartMinY = (minPrice * 0.95).clamp(0.0, double.infinity);
    final chartMaxY = maxPrice * 1.05;

    final spots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.price))
        .toList();

    final monthFmt = DateFormat('MMM');
    final showEveryLabel = points.length <= 6;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: chartMinY,
          maxY: chartMaxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (chartMaxY - chartMinY) / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: FieldColors.borderSubtle.withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: (chartMaxY - chartMinY) / 4,
                getTitlesWidget: (value, meta) {
                  if (value == meta.min || value == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _formatAxisPrice(value),
                      style: FieldTypography.labelSmall.copyWith(
                        fontSize: 10,
                        color: FieldColors.textMuted,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  if (!showEveryLabel && index.isOdd && index != points.length - 1) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      monthFmt.format(points[index].timestamp),
                      style: FieldTypography.labelSmall.copyWith(
                        fontSize: 10,
                        color: FieldColors.textMuted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 8,
              getTooltipColor: (_) => FieldColors.primaryNavy,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  final date = points[index].timestamp;
                  return LineTooltipItem(
                    'Rs. ${_formatTooltipPrice(spot.y)}\n${DateFormat('MMM yyyy').format(date)}',
                    FieldTypography.labelSmall.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  );
                }).toList();
              },
            ),
            getTouchedSpotIndicator: (barData, spotIndexes) {
              return spotIndexes.map((index) {
                return TouchedSpotIndicatorData(
                  const FlLine(color: Colors.transparent, strokeWidth: 0),
                  FlDotData(
                    getDotPainter: (spot, percent, bar, i) =>
                        FlDotCirclePainter(
                      radius: 5,
                      color: _lineColor,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
                  ),
                );
              }).toList();
            },
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: _lineColor,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                  radius: 3,
                  color: _lineColor,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _lineColor.withValues(alpha: 0.3),
                    _lineColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAxisPrice(double value) {
    if (value >= 1000) {
      final k = value / 1000;
      return '${k >= 10 ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  String _formatTooltipPrice(double value) {
    if (value >= 1000) {
      return value.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          );
    }
    return value.toStringAsFixed(0);
  }
}
