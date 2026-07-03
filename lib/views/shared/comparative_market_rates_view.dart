import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';

class ComparativeMarketRatesView extends StatelessWidget {
  const ComparativeMarketRatesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBg,
      appBar: AppBar(
        title: const Text('Pakistan Sourcing Market Indices'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildIndexCard(
            'Reinforcement Steel (Sarya) Grade 60 (Lahore)',
            'Rs. 260,000 / Ton',
            'Trend: +1.2% this week',
          ),
          _buildIndexCard(
            'OPC Cement Fauji (Rawalpindi)',
            'Rs. 1,450 / Bag',
            'Trend: -0.5% this week',
          ),
          _buildIndexCard(
            'Indus Coarse Sand (Karachi)',
            'Rs. 120 / Cft',
            'Trend: Stable',
          ),
        ],
      ),
    );
  }

  Widget _buildIndexCard(String item, String price, String trend) {
    final isNegative = trend.contains('-');
    final isStable = trend.contains('Stable');
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  trend,
                  style: GoogleFonts.plusJakartaSans(
                    color: isNegative
                        ? AppColors.error
                        : isStable
                            ? AppColors.textSecondary
                            : AppColors.success,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
