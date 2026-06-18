import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors (Skyline - Modern Enterprise UI)
  static const primary = Color(0xFF0EA5E9); // Skyline Blue
  static const primaryDark = Color(0xFF075985); // Darker Blue
  static const secondary = Color(0xFF0EA5E9); 
  
  // Surface Colors
  static const background = Color(0xFFFFFFFF); 
  static const surface = Color(0xFFF7F9FB); 
  static const border = Color(0xFFE2E8F0); 
  static const sidebarBackground = Color(0xFF0F172A); 
  static const infoBg = Color(0xFFF0F9FF); 
  static const successBg = Color(0xFFF0FDF4);
  static const dangerBg = Color(0xFFFEF2F2);
  
  // Role Accents
  static const ceoAccent = Color(0xFF6366F1); // Indigo
  static const supplierAccent = Color(0xFF0EA5E9); // Blue
  static const fieldAccent = Color(0xFF10B981); // Emerald
  static const adminAccent = Color(0xFF6C4FE0); // New Admin Accent
  
  // Text & Feedback
  static const textPrimary = Color(0xFF020617); 
  static const textSecondary = Color(0xFF94A3B8); 
  static const textMuted = Color(0xFF64748B);
  static const success = Color(0xFF10B981); 
  static const warning = Color(0xFFF59E0B); 
  static const error = Color(0xFFEF4444); 
  static const danger = Color(0xFFEF4444); 

  // Gradients & Overlays
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, Color(0xFF38BDF8)],
  );

  static const heroOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0xCC000000),
    ],
  );
}
