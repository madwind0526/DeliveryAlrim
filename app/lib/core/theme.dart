import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'system_user_font.dart';

/// App-wide dark theme with a neutral accent for a quieter delivery dashboard.
abstract final class AppTheme {
  static const accent = Color(0xFF8B8B92);
  static const primary = Color(0xFF8F8F8F);
  static const primaryContainer = Color(0xFF4A4A4E);
  static const secondaryContainer = Color(0xFF3F424A);

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: accent,
            brightness: Brightness.dark,
          ).copyWith(
            primary: primary,
            onPrimary: Colors.white,
            primaryContainer: primaryContainer,
            onPrimaryContainer: Colors.white,
            secondaryContainer: secondaryContainer,
            onSecondaryContainer: Colors.white,
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
