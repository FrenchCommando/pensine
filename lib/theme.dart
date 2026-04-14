import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Lofi color palette
class PensineColors {
  static const background = Color(0xFF1A1A2E);
  static const surface = Color(0xFF16213E);
  static const card = Color(0xFF0F3460);
  static const accent = Color(0xFFE94560);
  static const warm = Color(0xFFF5E6CC);
  static const muted = Color(0xFF8B8BAE);

  // Bubble colors for items
  static const bubbles = [
    Color(0xFFFF6B6B),
    Color(0xFFFFA07A),
    Color(0xFFFFD93D),
    Color(0xFF6BCB77),
    Color(0xFF4D96FF),
    Color(0xFF9B59B6),
    Color(0xFFFF85A1),
    Color(0xFF00C9A7),
  ];
}

ThemeData pensineTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: PensineColors.background,
    colorScheme: ColorScheme.dark(
      primary: PensineColors.accent,
      surface: PensineColors.surface,
    ),
    textTheme: GoogleFonts.quicksandTextTheme(
      ThemeData.dark().textTheme,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: GoogleFonts.quicksand(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: PensineColors.warm,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PensineColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: PensineColors.muted.withAlpha(80)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: PensineColors.muted.withAlpha(80)),
      ),
      hintStyle: TextStyle(color: PensineColors.muted),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: PensineColors.accent,
      foregroundColor: Colors.white,
    ),
  );
}
