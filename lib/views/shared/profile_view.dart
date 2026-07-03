import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';

class SharedProfileView extends StatelessWidget {
  const SharedProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBg,
      appBar: AppBar(title: const Text('Platform Identity card')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.amber.withValues(alpha: 0.15),
              child: const Icon(Icons.person, size: 50, color: AppColors.navy),
            ),
            const SizedBox(height: 16),
            Text(
              'Verified RateBridge User Profile',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
