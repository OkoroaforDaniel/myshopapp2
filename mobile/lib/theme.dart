import 'package:flutter/material.dart';

/// Brand palette copied from the website's `globals.css` so the app and the
/// site look like the same product.
class Brand {
  static const ink = Color(0xFF0F1222);
  static const muted = Color(0xFF6B7194);
  static const line = Color(0xFFECEAF3);
  static const bg = Color(0xFFF6F6F9);
  static const card = Colors.white;
  static const brand = Color(0xFFFF5A3C);
  static const brandDark = Color(0xFFE64A2E);
  static const amber = Color(0xFFFF9F1C);
  static const green = Color(0xFF16A34A);
  static const greenDark = Color(0xFF15803D);
  static const heroStart = Color(0xFF14142B);
  static const heroEnd = Color(0xFF232650);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Brand.brand,
      primary: Brand.brand,
      secondary: Brand.amber,
      surface: Brand.card,
    ),
    scaffoldBackgroundColor: Brand.bg,
    fontFamily: 'Roboto',
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Brand.ink,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 19,
        letterSpacing: -.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: Brand.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFECEAF3)),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.brand,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        shape: const StadiumBorder(),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF7F7FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFECEAF3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFECEAF3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Brand.brand, width: 1.6),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Brand.ink,
      contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
