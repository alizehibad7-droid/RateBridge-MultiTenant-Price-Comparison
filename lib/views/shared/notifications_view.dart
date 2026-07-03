import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';

class SharedNotificationsView extends StatelessWidget {
  const SharedNotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenBg,
      appBar: AppBar(title: const Text('Universal Announcements')),
      body: Center(
        child: Text(
          'All security updates and platform notices will show here.',
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
