import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF003FB1);
  static const primary2 = Color(0xFF0065D8);
  static const surfaceTint = Color(0xFFFAF8FF);
  static const success = Color(0xFF10A66B);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const text = Color(0xFF191B23);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFC3C5D7);
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      surface: AppColors.surfaceTint,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.surfaceTint,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.text,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF3F3FE),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          elevation: 3,
        ),
      ),
    );
  }

  static ThemeData dark() {
    final theme = light();
    return theme.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF101827),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary2,
        brightness: Brightness.dark,
      ),
      cardColor: const Color(0xFF162235),
    );
  }
}
