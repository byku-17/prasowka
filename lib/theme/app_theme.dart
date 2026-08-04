import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prasowka/providers/settings_provider.dart';

class AppTheme {
  // --- KOLORY KLASYCZNE (NAVY & GOLD) ---
  static const Color primaryNavy = Color(0xFF1E2126);
  static const Color accentGold = Color(0xFFF5B942);

  // --- KOLORY ELEGANCKIE (ECRU & SOFT GOLD) ---
  static const Color elegantEcru = Color(0xFFFCF9F2);
  static const Color elegantGold = Color(0xFFD4A017);

  // --- KOLORY ROYAL (PURPLE & WHITE) ---
  static const Color royalPurple = Color(0xFF905CFF);
  static const Color lightPurple = Color(0xFFE0D4FF);

  static ThemeData getTheme(AppThemeVariant variant, bool isDark, {ColorScheme? dynamicScheme}) {
    if (variant == AppThemeVariant.system && dynamicScheme != null) {
      return _buildDynamicTheme(dynamicScheme, isDark);
    }

    switch (variant) {
      case AppThemeVariant.elegantLight:
        return _buildElegantLightTheme();
      case AppThemeVariant.royalPurple:
        return isDark ? _buildRoyalDarkTheme() : _buildRoyalLightTheme();
      case AppThemeVariant.classic:
      default:
        return isDark ? _buildClassicDarkTheme() : _buildClassicLightTheme();
    }
  }

  // --- BUILDERY MOTYWÓW ---

  static ThemeData _buildClassicLightTheme() {
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
      ),
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryNavy,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
    );
  }

  static ThemeData _buildClassicDarkTheme() {
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
      ),
      scaffoldBackgroundColor: deepBlack,
      appBarTheme: const AppBarTheme(
        backgroundColor: deepBlack,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
    );
  }

  static ThemeData _buildElegantLightTheme() {
    final base = ThemeData.light();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: elegantGold,
      textTheme: GoogleFonts.syneTextTheme(base.textTheme),
      colorScheme: ColorScheme.fromSeed(
        seedColor: elegantGold,
        primary: elegantGold,
        secondary: elegantGold,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: elegantEcru,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ThemeData _buildRoyalLightTheme() {
    final base = ThemeData.light();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: royalPurple,
      textTheme: GoogleFonts.syneTextTheme(base.textTheme),
      colorScheme: ColorScheme.fromSeed(
        seedColor: royalPurple,
        primary: royalPurple,
        secondary: royalPurple,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFFBFBFF),
      appBarTheme: const AppBarTheme(
        backgroundColor: royalPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
    );
  }

  static ThemeData _buildRoyalDarkTheme() {
    const Color midnightPurple = Color(0xFF130E26);
    final base = ThemeData.dark();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: royalPurple,
      textTheme: GoogleFonts.syneTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: royalPurple,
        primary: royalPurple,
        secondary: lightPurple,
        surface: midnightPurple,
      ),
      scaffoldBackgroundColor: midnightPurple,
      appBarTheme: const AppBarTheme(
        backgroundColor: midnightPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
    );
  }

  static ThemeData _buildDynamicTheme(ColorScheme scheme, bool isDark) {
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      textTheme: GoogleFonts.syneTextTheme(isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: true,
      ),
    );
  }
}
