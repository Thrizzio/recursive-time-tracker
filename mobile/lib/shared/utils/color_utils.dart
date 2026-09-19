import 'package:flutter/material.dart';
import '../theme/chronolog_theme.dart';

/// Utility helpers for parsing and formatting activity colors.
class ColorUtils {
  ColorUtils._();

  /// Parses a hex color string (e.g. `#3b82f6`, `3b82f6`, `#fff`) or returns a fallback color.
  static Color parseHexColor(String? hexString, {Color fallback = ChronologTheme.cyan400}) {
    if (hexString == null || hexString.trim().isEmpty) {
      return fallback;
    }

    String hex = hexString.trim().replaceAll('#', '');
    if (hex.length == 3) {
      // #rgb -> #rrggbb
      hex = hex.split('').map((c) => '$c$c').join();
    }

    if (hex.length == 6) {
      hex = 'FF$hex';
    }

    final val = int.tryParse(hex, radix: 16);
    if (val == null) {
      return fallback;
    }

    return Color(val);
  }
}
