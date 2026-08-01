import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    // Resolved locally: building a theme must never mutate shared state, or
    // whichever of light()/dark() runs last decides the palette for the whole
    // app.
    final c = Palette.of(brightness);
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: c.background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.accent,
        onPrimary: AppColors.onAccent,
        secondary: c.success,
        onSecondary: AppColors.white,
        surface: c.surface,
        onSurface: c.textPrimary,
        error: c.danger,
        onError: AppColors.white,
      ),
      textTheme: _textTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      dividerTheme: DividerThemeData(
        color: c.divider,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: c.textTertiary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size.fromHeight(52),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.divider),
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.divider,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.background,
        selectedItemColor: c.accent,
        unselectedItemColor: c.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceElevated,
        selectedColor: c.accentDim,
        labelStyle: TextStyle(color: c.textPrimary, fontSize: 13),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceElevated,
        contentTextStyle: TextStyle(color: c.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base
        .apply(
          bodyColor: c.textPrimary,
          displayColor: c.textPrimary,
        )
        .copyWith(
          titleLarge: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, height: 1.4),
          titleMedium: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, height: 1.4),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.6),
          bodySmall: TextStyle(
              fontSize: 12, height: 1.5, color: c.textSecondary),
        );
  }
}
