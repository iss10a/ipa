import 'package:flutter/material.dart';

/// An immutable set of colours resolved for one brightness.
///
/// Kept as a value object so building a ThemeData never mutates shared state.
/// The previous design had both AppTheme.light() and AppTheme.dark() writing a
/// static brightness flag while they built, so whichever ran last decided the
/// palette for the whole app - which is how light text ended up on a white
/// background.
@immutable
class Palette {
  const Palette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.divider,
    required this.accent,
    required this.accentDim,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.danger,
  });

  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color divider;
  final Color accent;
  final Color accentDim;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color success;
  final Color danger;

  Color get warning => accent;
  Color get info => success;

  static const Palette light = Palette(
    background: AppColors.white,
    surface: Color(0xFFF7F8FA),
    surfaceElevated: Color(0xFFEFF1F4),
    divider: Color(0xFFDDE1E6),
    accent: AppColors.red,
    accentDim: Color(0xFFF6DDE2),
    textPrimary: Color(0xFF14171C),
    textSecondary: Color(0xFF565E6B),
    textTertiary: Color(0xFF8A929E),
    success: AppColors.green,
    danger: AppColors.red,
  );

  static const Palette dark = Palette(
    background: Color(0xFF0E1013),
    surface: Color(0xFF171A1F),
    surfaceElevated: Color(0xFF20242B),
    divider: Color(0xFF2C3138),
    // Lifted slightly so red keeps its punch against a dark surface.
    accent: Color(0xFFE84257),
    accentDim: Color(0xFF3A1720),
    textPrimary: Color(0xFFF1F3F6),
    textSecondary: Color(0xFFA8B0BC),
    textTertiary: Color(0xFF757E8B),
    success: Color(0xFF12A65A),
    danger: Color(0xFFE84257),
  );

  static Palette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// Oman flag palette, and nothing else.
///
/// Red carries every primary action and all progress. Green marks success and
/// completion. Everything else is white or a neutral derived from it.
class AppColors {
  AppColors._();

  // --- flag colours, identical in both modes -------------------------------
  static const Color red = Color(0xFFC8102E);
  static const Color green = Color(0xFF007A3D);
  static const Color white = Color(0xFFFFFFFF);

  /// Set once per frame by the MaterialApp builder, from the brightness that
  /// actually won. This is the only writer.
  static Palette _current = Palette.light;

  static void apply(Brightness brightness) =>
      _current = Palette.of(brightness);

  static Color get background => _current.background;
  static Color get surface => _current.surface;
  static Color get surfaceElevated => _current.surfaceElevated;
  static Color get divider => _current.divider;
  static Color get accent => _current.accent;
  static Color get accentDim => _current.accentDim;
  static Color get textPrimary => _current.textPrimary;
  static Color get textSecondary => _current.textSecondary;
  static Color get textTertiary => _current.textTertiary;
  static Color get success => _current.success;
  static Color get danger => _current.danger;
  static Color get warning => _current.warning;
  static Color get info => _current.info;

  /// Text and icons drawn over poster artwork are always light, in both modes,
  /// because the scrim beneath them is always dark.
  static const Color onImage = white;

  /// Foreground for anything filled with [accent].
  static const Color onAccent = white;

  static const LinearGradient bannerScrim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0xB3000000), Color(0xF0000000)],
    stops: [0.0, 0.65, 1.0],
  );
}
