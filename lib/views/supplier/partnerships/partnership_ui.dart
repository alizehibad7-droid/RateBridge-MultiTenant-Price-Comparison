import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/supplier_theme.dart';

const partnershipCities = [
  'All',
  'Rawalpindi',
  'Islamabad',
  'Lahore',
  'Karachi',
  'Peshawar',
];

BoxDecoration partnershipCardDecoration({Color? borderColor}) => BoxDecoration(
      color: FieldColors.surfaceWhite,
      borderRadius: BorderRadius.circular(12),
      border: borderColor != null
          ? Border.all(color: borderColor)
          : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

Widget partnershipSectionHeader(String label) => Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: FieldColors.textSecondary,
        ),
      ),
    );

Widget companyInitialsAvatar(String name, {double size = 40}) {
  final initial =
      name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'C';
  return CircleAvatar(
    radius: size / 2,
    backgroundColor: FieldColors.primaryNavy,
    child: Text(
      initial,
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: size * 0.38,
      ),
    ),
  );
}

String partnershipDaysAgo(DateTime date) {
  final days = DateTime.now().difference(date).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return '1 day ago';
  return '$days days ago';
}

Widget partnershipEmptyState({
  required IconData icon,
  required String title,
  required String subtitle,
  required String buttonLabel,
  required VoidCallback onBrowse,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
    child: Column(
      children: [
        Icon(icon, size: 64, color: FieldColors.textMuted),
        const SizedBox(height: 16),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: FieldColors.primaryNavy,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: FieldColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onBrowse,
            child: Text(buttonLabel),
          ),
        ),
      ],
    ),
  );
}
