// MVVM: View — no business logic

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../utils/app_theme.dart';
import '../../constants/app_colors.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/field_user_viewmodel.dart';
import '../../models/price_trend_model.dart';

class FieldPriceTrendsView extends StatefulWidget {
  final String materialName;

  const FieldPriceTrendsView({super.key, required this.materialName});

  @override
  State<FieldPriceTrendsView> createState() => _FieldPriceTrendsViewState();
}

class _FieldPriceTrendsViewState extends State<FieldPriceTrendsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final companyId = context.read<AuthViewModel>().companyId;
      if (companyId != null) {
        context
            .read<FieldUserViewModel>()
            .loadPriceTrend(companyId, widget.materialName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fieldVm = context.watch<FieldUserViewModel>();
    final points = fieldVm.priceTrend;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('${widget.materialName} — Price Trend',
            style: AppTextStyles.h3),
      ),
      body: fieldVm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DirectionBanner(direction: fieldVm.trendDirection),
                  const SizedBox(height: 16),
                  if (points.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: appCardDecoration(shadow: AppShadows.card),
                      child: Column(
                        children: [
                          const Icon(Icons.show_chart,
                              size: 40, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            fieldVm.trendInsight ??
                                'No price history available yet.',
                            style: AppTextStyles.bodyMuted,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: appCardDecoration(shadow: AppShadows.card),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const _LegendDot(
                                  color: AppColors.fieldAccent,
                                  label: 'History'),
                              const SizedBox(width: 16),
                              const _LegendDot(
                                  color: AppColors.adminAccent,
                                  label: 'AI Forecast'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 220,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: _PriceTrendPainter(points: points),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (fieldVm.trendInsight != null && points.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: appCardDecoration(
                        shadow: AppShadows.card,
                        borderColor: AppColors.primary.withOpacity(0.2),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.auto_awesome,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              fieldVm.trendInsight!,
                              style: AppTextStyles.bodyMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _DirectionBanner extends StatelessWidget {
  final String direction;

  const _DirectionBanner({required this.direction});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String label;

    switch (direction) {
      case 'up':
        icon = Icons.trending_up;
        color = AppColors.danger;
        label = 'Prices are trending up — consider ordering soon.';
        break;
      case 'down':
        icon = Icons.trending_down;
        color = AppColors.success;
        label = 'Prices are trending down — you may save by waiting.';
        break;
      default:
        icon = Icons.trending_flat;
        color = AppColors.primary;
        label = 'Prices have been stable recently.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.12), color.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration:
                const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: AppTextStyles.h3),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 3, color: color),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.bodyMuted),
      ],
    );
  }
}

class _PriceTrendPainter extends CustomPainter {
  final List<PriceTrendPoint> points;

  _PriceTrendPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final prices = points.map((p) => p.price).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final range = (maxPrice - minPrice) == 0 ? 1 : (maxPrice - minPrice);

    final chartHeight = size.height - 24;
    final stepX = size.width / (points.length - 1);

    Offset offsetFor(int i) {
      final normalized = (points[i].price - minPrice) / range;
      final y = chartHeight - (normalized * chartHeight) + 12;
      return Offset(i * stepX, y);
    }

    final gridPaint = Paint()
      ..color = AppColors.border.withOpacity(0.5)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chartHeight * (i / 3) + 12;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final splitIndex = points.indexWhere((p) => p.isForecast);
    final hasForecast = splitIndex != -1;

    final historyPaint = Paint()
      ..color = AppColors.fieldAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final historyPath = Path();
    final historyEnd = hasForecast ? splitIndex : points.length - 1;
    for (var i = 0; i <= historyEnd; i++) {
      final o = offsetFor(i);
      if (i == 0) {
        historyPath.moveTo(o.dx, o.dy);
      } else {
        historyPath.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(historyPath, historyPaint);

    if (hasForecast) {
      final forecastPaint = Paint()
        ..color = AppColors.adminAccent
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (var i = splitIndex - 1; i < points.length - 1; i++) {
        if (i < 0) continue;
        final p1 = offsetFor(i);
        final p2 = offsetFor(i + 1);
        _drawDashedLine(canvas, p1, p2, forecastPaint);
      }
    }

    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < points.length; i++) {
      final o = offsetFor(i);
      dotPaint.color = points[i].isForecast
          ? AppColors.adminAccent
          : AppColors.fieldAccent;
      canvas.drawCircle(o, 3.5, dotPaint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final total = (end - start).distance;
    final dir = (end - start) / total;
    var distance = 0.0;
    while (distance < total) {
      final from = start + dir * distance;
      final remaining = total - distance;
      final segment = remaining < dashWidth ? remaining : dashWidth;
      final to = from + dir * segment;
      canvas.drawLine(from, to, paint);
      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _PriceTrendPainter oldDelegate) =>
      oldDelegate.points != points;
}
