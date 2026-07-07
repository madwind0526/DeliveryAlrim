import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'system_user_font.dart';

/// App-wide light/dark themes with a neutral accent for a quieter delivery
/// dashboard. Both modes manually override the seed-generated primary/
/// container colors (rather than trusting Material's tonal defaults) so the
/// muted, low-saturation look stays consistent in both brightnesses while
/// keeping text contrast safe.
abstract final class AppTheme {
  static const accent = Color(0xFF8B8B92);

  // Dark mode overrides.
  static const _darkPrimary = Color(0xFF8F8F8F);
  static const _darkPrimaryContainer = Color(0xFF4A4A4E);
  static const _darkSecondaryContainer = Color(0xFF3F424A);

  // Light mode overrides. Primary is kept dark enough that white text/icons
  // on it stay readable (~5.8:1 contrast); containers are light neutrals
  // paired with near-black text for legibility on white surfaces.
  static const _lightPrimary = Color(0xFF5B5B60);
  static const _lightPrimaryContainer = Color(0xFFE2E1E6);
  static const _lightOnPrimaryContainer = Color(0xFF29292D);
  static const _lightSecondaryContainer = Color(0xFFE3E5EA);
  static const _lightOnSecondaryContainer = Color(0xFF2B2E35);
  static const _lightSurface = Color(0xFFFAFAFA);
  static const _lightOnSurface = Color(0xFF1B1B1D);
  static const _lightOnSurfaceVariant = Color(0xFF48484C);

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: accent,
            brightness: Brightness.dark,
          ).copyWith(
            primary: _darkPrimary,
            onPrimary: Colors.white,
            primaryContainer: _darkPrimaryContainer,
            onPrimaryContainer: Colors.white,
            secondaryContainer: _darkSecondaryContainer,
            onSecondaryContainer: Colors.white,
          ),
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      fontFamily: SystemUserFont.activeFamily ?? _systemFontFamily,
    );
  }

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: accent,
            brightness: Brightness.light,
          ).copyWith(
            primary: _lightPrimary,
            onPrimary: Colors.white,
            primaryContainer: _lightPrimaryContainer,
            onPrimaryContainer: _lightOnPrimaryContainer,
            secondaryContainer: _lightSecondaryContainer,
            onSecondaryContainer: _lightOnSecondaryContainer,
            surface: _lightSurface,
            onSurface: _lightOnSurface,
            onSurfaceVariant: _lightOnSurfaceVariant,
          ),
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      fontFamily: SystemUserFont.activeFamily ?? _systemFontFamily,
    );
  }

  static String? get _systemFontFamily => switch (defaultTargetPlatform) {
    TargetPlatform.windows => 'Segoe UI',
    TargetPlatform.macOS => '.AppleSystemUIFont',
    TargetPlatform.iOS => '.SF Pro Text',
    _ => null,
  };
}
