import 'package:flutter/material.dart';

/// Design tokens and Material 3 theme matching Chronolog's web design system:
/// dark zinc surfaces, cyan accents, and clear typography.
class ChronologTheme {
  ChronologTheme._();

  // Zinc Palette
  static const Color zinc950 = Color(0xFF09090B); // Background
  static const Color zinc900 = Color(0xFF18181B); // Card & surface
  static const Color zinc800 = Color(0xFF27272A); // Borders / dividers
  static const Color zinc700 = Color(0xFF3F3F46); // Secondary borders
  static const Color zinc600 = Color(0xFF52525B); // Subtle icons
  static const Color zinc500 = Color(0xFF71717A); // Muted captions
  static const Color zinc400 = Color(0xFFA1A1AA); // Secondary text
  static const Color zinc300 = Color(0xFFD4D4D8); // Subtle text
  static const Color zinc200 = Color(0xFFE4E4E7); // Prominent text
  static const Color zinc50 = Color(0xFFFAFAFA);  // Primary text

  // Accent & Functional Palette
  static const Color cyan400 = Color(0xFF22D3EE); // Primary brand accent
  static const Color cyan300 = Color(0xFF67E8F9); // Bright buttons / CTA
  static const Color cyan950 = Color(0xFF083344); // Tinted badge background
  static const Color red400 = Color(0xFFF87171);  // Error text
  static const Color red950 = Color(0xFF450A0A);  // Error background
  static const Color emerald400 = Color(0xFF34D399); // Success text
  static const Color emerald950 = Color(0xFF064E3B); // Success background

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: zinc950,
      canvasColor: zinc950,
      colorScheme: const ColorScheme.dark(
        surface: zinc900,
        primary: cyan400,
        onPrimary: zinc950,
        secondary: cyan300,
        onSecondary: zinc950,
        error: red400,
        onError: zinc950,
        outline: zinc800,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: zinc950,
        foregroundColor: zinc50,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: zinc50,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: zinc900,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: zinc800, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cyan300,
          foregroundColor: zinc950,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: zinc300,
          side: const BorderSide(color: zinc700),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: zinc50,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.6,
        ),
        headlineMedium: TextStyle(
          color: zinc50,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: TextStyle(
          color: zinc50,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: zinc200,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: zinc200,
          fontSize: 15,
        ),
        bodyMedium: TextStyle(
          color: zinc300,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: zinc400,
          fontSize: 12,
        ),
        labelSmall: TextStyle(
          color: cyan400,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: zinc900,
        selectedItemColor: cyan400,
        unselectedItemColor: zinc400,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: zinc800,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

