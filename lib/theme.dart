import 'package:flutter/material.dart';

// Lofi color palette
class PensineColors {
  static const accent = Color(0xFFE94560);
  static const warm = Color(0xFFF5E6CC);

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

  /// Returns the board's accent color, or the default accent if colorIndex is -1.
  static Color boardAccent(int colorIndex) =>
      colorIndex >= 0 ? bubbles[colorIndex % bubbles.length] : accent;

  // Context-aware colors — use these in widgets
  static Color background(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  static Color surface(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
  static Color muted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF8B8BAE)
          : const Color(0xFF8B8B9E);
  static Color card(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F3460)
          : const Color(0xFFE8E0D8);
}

ThemeData pensineTheme({Brightness brightness = Brightness.dark}) {
  final isDark = brightness == Brightness.dark;
  final bg = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF5F0EB);
  final sf = isDark ? const Color(0xFF16213E) : const Color(0xFFFFFFFF);
  final mt = isDark ? const Color(0xFF8B8BAE) : const Color(0xFF8B8B9E);
  final tt = isDark ? PensineColors.warm : const Color(0xFF4A3728);
  final base = isDark ? ThemeData.dark() : ThemeData.light();

  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: bg,
    colorScheme: isDark
        ? ColorScheme.dark(primary: PensineColors.accent, surface: sf)
        : ColorScheme.light(primary: PensineColors.accent, surface: sf),
    textTheme: base.textTheme.apply(fontFamily: 'Quicksand'),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Quicksand',
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: tt,
      ),
      iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: mt.withAlpha(80)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: mt.withAlpha(80)),
      ),
      hintStyle: TextStyle(color: mt),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: PensineColors.accent,
      foregroundColor: Colors.white,
    ),
  );
}
