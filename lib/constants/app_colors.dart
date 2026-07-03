import 'package:flutter/material.dart';

/// Official RateBridge design tokens (global).
class AppColors {
  AppColors._();

  // Brand
  static const navy = Color(0xFF1E326E);
  static const amber = Color(0xFFFBB03C);
  static const darkAmber = Color(0xFFB7791F);

  // Surfaces
  static const screenBg = Color(0xFFF5F6FA);
  static const background = screenBg;
  static const surface = screenBg;
  static const card = Colors.white;
  static const border = Color(0xFFE2E5F0);

  // Legacy aliases used across auth / shared code
  static const primary = navy;
  static const primaryDark = navy;
  static const secondary = amber;
  static const sidebarBackground = navy;
  static const infoBg = Color(0x261E326E);
  static const successBg = Color(0x261D9E75);
  static const dangerBg = Color(0x26E25730);

  // Role accents (auth forms use amber uniformly)
  static const ceoAccent = amber;
  static const supplierAccent = amber;
  static const fieldAccent = amber;
  static const adminAccent = navy;

  // Text & feedback
  static const textPrimary = navy;
  static const textSecondary = Color(0xFF888888);
  static const textMuted = Color(0xFF888888);
  static const success = Color(0xFF1D9E75);
  static const warning = amber;
  static const error = Color(0xFFE25730);
  static const danger = error;

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, Color(0xFF2A4089)],
  );

  static const heroOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xCC000000)],
  );
}
