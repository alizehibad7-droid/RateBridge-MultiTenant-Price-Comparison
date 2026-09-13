import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/field_theme.dart';

class AppRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double pill = 99.0;
}

class AppShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}

TextStyle _plusJakarta({
  required double fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
  double? letterSpacing,
}) {
  return GoogleFonts.plusJakartaSans(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

class AppTextStyles {
  static TextStyle get h1 => _plusJakarta(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: FieldColors.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get h2 => _plusJakarta(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: FieldColors.textPrimary,
        letterSpacing: -0.4,
      );

  static TextStyle get h3 => _plusJakarta(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: FieldColors.textPrimary,
      );

  static TextStyle get label => _plusJakarta(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: FieldColors.textSecondary,
        letterSpacing: 1.1,
      );

  static TextStyle get body => _plusJakarta(
        fontSize: 15,
        color: FieldColors.textPrimary,
        height: 1.5,
      );

  static TextStyle get bodyMuted => _plusJakarta(
        fontSize: 14,
        color: FieldColors.textSecondary,
        height: 1.5,
      );

  static TextStyle get caption => _plusJakarta(
        fontSize: 12,
        color: FieldColors.textSecondary,
      );

  static TextStyle get button => _plusJakarta(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 0.3,
      );

  static TextStyle get emptyTitle => _plusJakarta(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: FieldColors.textMuted,
      );

  static TextStyle get emptySubtitle => _plusJakarta(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: FieldColors.textSecondary,
        height: 1.5,
      );
}

BoxDecoration appCardDecoration({
  List<BoxShadow>? shadow,
  Color? borderColor,
}) {
  return BoxDecoration(
    color: FieldColors.surfaceWhite,
    borderRadius: BorderRadius.circular(FieldRadius.card),
    border: Border.all(
      color: borderColor ?? FieldColors.borderSubtle,
      width: 1,
    ),
    boxShadow: shadow,
  );
}
