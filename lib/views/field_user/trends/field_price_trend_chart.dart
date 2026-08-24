import 'dart:math' as math;

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
    final ticks = _niceTicks(minPrice, maxPrice);
    final interval = ticks.length > 1 ? ticks[1] - ticks[0] : 1.0;
    final chartMinY = ticks.first;
    final chartMaxY = ticks.last;

    final spots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.price))
        .toList();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: chartMinY,
          maxY: chartMaxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: FieldColors.borderSubtle.withValues(alpha: 0.45),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  if (!_isTick(value, ticks, interval)) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _formatAxisPrice(value, interval),
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
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if ((value - index).abs() > 0.01) {
                    return const SizedBox.shrink();
                  }
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  if (!_shouldShowXLabel(index, points.length)) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _xAxisLabel(points, index),
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
                  final index = spot.x.toInt().clamp(0, points.length - 1);
                  final date = points[index].timestamp;
                  return LineTooltipItem(
                    'Rs. ${_formatTooltipPrice(spot.y)}\n${DateFormat('d MMM yyyy').format(date)}',
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

  static bool _isTick(double value, List<double> ticks, double interval) {
    final threshold = math.max(interval.abs() * 0.01, 0.01);
    return ticks.any((tick) => (tick - value).abs() <= threshold);
  }

  static List<double> _niceTicks(double minPrice, double maxPrice) {
    var lo = minPrice;
    var hi = maxPrice;
    if (hi < lo) {
      final swap = lo;
      lo = hi;
      hi = swap;
    }

    if (hi - lo < 1e-6) {
      final pad = math.max(lo.abs() * 0.08, 500.0);
      lo = math.max(0, lo - pad);
      hi = hi + pad;
    } else {
      final pad = (hi - lo) * 0.12;
      lo = math.max(0, lo - pad);
      hi = hi + pad;
    }

    const targetCount = 4;
    final niceRange = _niceNum(hi - lo, round: false);
    var interval = _niceNum(niceRange / (targetCount - 1), round: true);
    if (interval <= 0) interval = 1;

    final niceMin = (lo / interval).floor() * interval;
    final niceMax = (hi / interval).ceil() * interval;

    final ticks = <double>[];
    for (var value = niceMin; value <= niceMax + interval / 2; value += interval) {
      ticks.add(value);
    }
    if (ticks.length < 2) {
      return [niceMin, niceMin + interval];
    }
    return ticks;
  }

  static double _niceNum(double range, {required bool round}) {
    final safeRange = range <= 0 ? 1.0 : range;
    final exponent = (math.log(safeRange) / math.ln10).floor();
    final fraction = safeRange / math.pow(10, exponent);
    final double niceFraction;
    if (round) {
      if (fraction < 1.5) {
        niceFraction = 1;
      } else if (fraction < 3) {
        niceFraction = 2;
      } else if (fraction < 7) {
        niceFraction = 5;
      } else {
        niceFraction = 10;
      }
    } else {
      if (fraction <= 1) {
        niceFraction = 1;
      } else if (fraction <= 2) {
        niceFraction = 2;
      } else if (fraction <= 5) {
        niceFraction = 5;
      } else {
        niceFraction = 10;
      }
    }
    return niceFraction * math.pow(10, exponent);
  }

  static bool _shouldShowXLabel(int index, int length) {
    if (length <= 4) return true;
    if (index == 0 || index == length - 1) return true;
    if (length <= 8) return index.isEven;
    final step = (length / 3).floor().clamp(1, length);
    return index % step == 0;
  }

  static String _xAxisLabel(List<PriceHistoryModel> points, int index) {
    final date = points[index].timestamp;
    final sameMonth = points.every(
      (point) =>
          point.timestamp.year == date.year &&
          point.timestamp.month == date.month,
    );
    if (sameMonth) {
      return DateFormat('d MMM').format(date);
    }
    final sameYear = points.every((point) => point.timestamp.year == date.year);
    if (sameYear) {
      return DateFormat('d MMM').format(date);
    }
    return DateFormat('MMM y').format(date);
  }

  static String _formatAxisPrice(double value, double interval) {
    if (interval >= 1000) {
      final k = value / 1000;
      if ((k - k.roundToDouble()).abs() < 0.05) {
        return '${k.round()}K';
      }
      return '${k.toStringAsFixed(1)}K';
    }
    if (value >= 1000) {
      return NumberFormat('#,##0').format(value.round());
    }
    return value.round().toString();
  }

  static String _formatTooltipPrice(double value) {
    return NumberFormat('#,##0').format(value.round());
  }
}
