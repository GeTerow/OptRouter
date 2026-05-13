import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const primary = Color(0xFF2563EB);
  static const background = Color(0xFFF3F4F6);
  static const surface = Colors.white;
  static const textStrong = Color(0xFF111827);
  static const text = Color(0xFF1F2937);
  static const textSecondary = Color(0xFF374151);
  static const textMuted = Color(0xFF6B7280);
  static const textSubtle = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const secondaryButton = Color(0xFFE5E7EB);
  static const disabledButton = Color(0xFFD1D5DB);
  static const overlay = Color(0xFF111827);
  static const overlayText = Color(0xFFF9FAFB);
}

class AppRadii {
  const AppRadii._();

  static const button = 12.0;
  static const card = 12.0;
  static const largeCard = 14.0;
  static const overlay = 16.0;
}

class AppSpacing {
  const AppSpacing._();

  static const screenHorizontal = 20.0;
  static const footerVertical = 12.0;
}

class AppShadows {
  const AppShadows._();

  static const card = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static const overlay = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
      ),
      fontFamily: 'Roboto',
    );
  }
}
