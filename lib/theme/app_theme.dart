import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Główne kolory marki
  static const Color primaryNavy = Color(0xFF1E2126);
  static const Color accentGold = Color(0xFFF5B942);
  
  // Kolory tła i tekstu
  static const Color lightBg = Color(0xFFF8F9FA);

  /// Motyw Jasny
  static ThemeData get lightTheme {
    final base = ThemeData.light();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryNavy,
      textTheme: GoogleFonts.syneTextTheme(base.textTheme),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryNavy,
        primary: primaryNavy,
        secondary: accentGold,
        surface: Colors.white,
        error: Colors.redAccent,
      ),
      scaffoldBackgroundColor: lightBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
      ),
    );
  }

  /// Motyw Ciemny
  static ThemeData get darkTheme {
    const Color deepBlack = Color(0xFF1E2126);
    final base = ThemeData.dark();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryNavy,
      textTheme: GoogleFonts.syneTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: primaryNavy,
        primary: accentGold,
        secondary: accentGold,
        surface: deepBlack,
        error: Colors.redAccent,
      ),
      scaffoldBackgroundColor: deepBlack,
      appBarTheme: const AppBarTheme(
        backgroundColor: deepBlack,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        color: deepBlack,
      ),
    );
  }
}
