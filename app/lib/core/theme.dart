import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'system_user_font.dart';

/// App-wide dark theme. Accent colors match the existing desktop-tools
/// design system (#7c6af7 accent, #f87171 danger, #4ade80 success).
abstract final class AppTheme {
  static const accent = Color(0xFF7C6AF7);

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
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
