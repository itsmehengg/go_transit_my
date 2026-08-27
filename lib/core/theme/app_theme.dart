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
  static const darkBackground = Color(0xFF0B1220);
  static const darkSurface = Color(0xFF151F2E);
  static const darkSurfaceHigh = Color(0xFF1D2A3B);
  static const darkText = Color(0xFFF8FAFC);
  static const darkMuted = Color(0xFFCBD5E1);
  static const darkLine = Color(0xFF41516A);
}

class AppTheme {
  static TextTheme _textTheme(Color primaryText, Color secondaryText) {
    const base = TextTheme(
      displayLarge: TextStyle(fontSize: 57, fontWeight: FontWeight.w400),
      displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400),
      displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400),
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    );

    return base.copyWith(
      displayLarge: base.displayLarge!.copyWith(color: primaryText),
      displayMedium: base.displayMedium!.copyWith(color: primaryText),
      displaySmall: base.displaySmall!.copyWith(color: primaryText),
      headlineLarge: base.headlineLarge!.copyWith(color: primaryText),
      headlineMedium: base.headlineMedium!.copyWith(color: primaryText),
      headlineSmall: base.headlineSmall!.copyWith(color: primaryText),
      titleLarge: base.titleLarge!.copyWith(color: primaryText),
      titleMedium: base.titleMedium!.copyWith(color: primaryText),
      titleSmall: base.titleSmall!.copyWith(color: primaryText),
      bodyLarge: base.bodyLarge!.copyWith(color: primaryText),
      bodyMedium: base.bodyMedium!.copyWith(color: primaryText),
      bodySmall: base.bodySmall!.copyWith(color: secondaryText),
      labelLarge: base.labelLarge!.copyWith(color: primaryText),
      labelMedium: base.labelMedium!.copyWith(color: primaryText),
      labelSmall: base.labelSmall!.copyWith(color: secondaryText),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      surface: AppColors.surfaceTint,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.surfaceTint,
      fontFamily: 'Inter',
      textTheme: _textTheme(AppColors.text, AppColors.muted),
      iconTheme: const IconThemeData(color: AppColors.text),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.text,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF3F3FE),
        labelStyle: const TextStyle(color: AppColors.muted),
        hintStyle: const TextStyle(color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 18),
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
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Color(0xFFE6EEFF),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
        ),
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: AppColors.text)),
      ),
      dividerColor: AppColors.line,
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B9DFF),
      brightness: Brightness.dark,
      primary: const Color(0xFF79AFFF),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      canvasColor: AppColors.darkBackground,
      cardColor: AppColors.darkSurface,
      dividerColor: AppColors.darkLine,
      fontFamily: 'Inter',
      textTheme: _textTheme(AppColors.darkText, AppColors.darkMuted),
      iconTheme: const IconThemeData(color: AppColors.darkText),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkText,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.darkText,
        iconColor: AppColors.darkText,
        subtitleTextStyle: TextStyle(color: AppColors.darkMuted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceHigh,
        labelStyle: const TextStyle(color: AppColors.darkMuted),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        prefixIconColor: AppColors.darkMuted,
        suffixIconColor: AppColors.darkMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF79AFFF), width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          backgroundColor: const Color(0xFF2F6FE4),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          elevation: 2,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkText,
          side: const BorderSide(color: AppColors.darkLine),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: const Color(0xFF8BB8FF)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xFFCBD5E1);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? const Color(0xFF2F6FE4)
              : const Color(0xFF475569);
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF111A28),
        indicatorColor: const Color(0xFF254C85),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.darkMuted,
            fontWeight: FontWeight.w700,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? Colors.white
                : AppColors.darkMuted,
          );
        }),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        titleTextStyle: TextStyle(
          color: AppColors.darkText,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(color: AppColors.darkMuted),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF243244),
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    );
  }
}
