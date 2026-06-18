import 'package:flutter/material.dart';

class ComparativeMarketRatesView extends StatelessWidget {
  const ComparativeMarketRatesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const Text("Pakistan Sourcing Market Indices"), backgroundColor: const Color(0xFF1E293B)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildIndexCard("Reinforcement Steel (Sarya) Grade 60 (Lahore)", "Rs. 260,000 / Ton", "Trend: +1.2% this week"),
          _buildIndexCard("OPC Cement Fauji (Rawalpindi)", "Rs. 1,450 / Bag", "Trend: -0.5% this week"),
          _buildIndexCard("Indus Coarse Sand (Karachi)", "Rs. 120 / Cft", "Trend: Stable"),
        ],
      ),
    );
  }

  Widget _buildIndexCard(String item, String price, String trend) {
    final isNegative = trend.contains('-');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(trend, style: TextStyle(color: isNegative ? Colors.redAccent : const Color(0xFF34D399), fontSize: 11)),
              ],
            ),
          ),
          Text(price, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
