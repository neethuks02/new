import 'package:flutter/material.dart';

class AppColors {
  // Primary Palette
  static const Color primary = Color(0xFF1E3A8A); // Deep Blue/Indigo
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF172554);
  static const Color accent = Color(0xFF38BDF8); // Sky Blue Accent

  // Background and Surface Colors
  static const Color background = Color(0xFFF8FAFC); // Soft Gray Background
  static const Color surface = Colors.white; // Crisp White
  static const Color surfaceVariant = Color(0xFFF1F5F9);

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A); // Very dark slate
  static const Color textSecondary = Color(0xFF64748B); // Slate gray

  // Status Colors
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color successBackground = Color(0xFFD1FAE5);
  
  static const Color warning = Color(0xFFF59E0B); // Amber/Orange
  static const Color warningBackground = Color(0xFFFEF3C7);
  
  static const Color error = Color(0xFFEF4444); // Red
  static const Color errorBackground = Color(0xFFFEE2E2);
  
  static const Color info = Color(0xFF3B82F6); // Blue
  static const Color infoBackground = Color(0xFFDBEAFE);

  // Shadows
  static List<BoxShadow> get premiumShadow => [
    BoxShadow(
      color: primaryDark.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: primaryDark.withOpacity(0.02),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}
