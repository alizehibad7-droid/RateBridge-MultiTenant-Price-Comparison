import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';
import '../../utils/app_navigation.dart';

class LedgerView extends StatelessWidget {
  const LedgerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: AppNavigation.leading(context),
        title: const Text('B2B Corporate Ledgers'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildItem(
            'PO-88129-LHE',
            'ASTM Grade 60 Rebars',
            'PKR 3,900,000',
            'Released',
          ),
          _buildItem(
            'PO-88132-RWP',
            'Fauji Cement Premium Slurry',
            'PKR 725,000',
            'Released',
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    String tracking,
    String materialName,
    String volume,
    String status,
  ) {
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tracking,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                materialName,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                volume,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                status,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
