import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class PriceTrendChartWidget extends StatelessWidget {
  final List<double> prices;

  const PriceTrendChartWidget({super.key, required this.prices});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: prices.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
              isCurved: true,
              color: const Color(0xFF6366F1),
              barWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
