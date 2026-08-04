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

  // --- KOLORY MEDIUM (SLATE & AMBER) ---
  static const Color mediumSlate = Color(0xFF2D3138);      // surface - między biały a #1E2126
  static const Color mediumSlateLight = Color(0xFF3A3F48); // elevated surface
  static const Color mediumSlateDark = Color(0xFF1E2126);  // deep surface
  static const Color mediumAmber = Color(0xFFFFB800);      // modern amber accent
  static const Color mediumBackground = Color(0xFF25292E); // scaffold bg

  static ThemeData getTheme(AppThemeVariant variant, bool isDark, {ColorScheme? dynamicScheme}) {
    if (variant == AppThemeVariant.system && dynamicScheme != null) {
      return _buildDynamicTheme(dynamicScheme, isDark);
    }

    switch (variant) {
      case AppThemeVariant.elegantLight:
        return _buildElegantLightTheme();
      case AppThemeVariant.royalPurple:
        return isDark ? _buildRoyalDarkTheme() : _buildRoyalLightTheme();
      case AppThemeVariant.medium:
        return _buildMediumTheme();
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
      cardTheme: CardThemeData(
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

  // --- MEDIUM THEME (SLATE & AMBER) - między jasnym a ciemnym ---
  static ThemeData _buildMediumTheme() {
    final base = ThemeData.dark();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: mediumSlate,
      textTheme: GoogleFonts.syneTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      colorScheme: ColorScheme(
        brightness: Brightness.dark,
        primary: mediumAmber,
        onPrimary: Colors.black,
        secondary: mediumAmber,
        onSecondary: Colors.black,
        tertiary: mediumSlateLight,
        onTertiary: Colors.white,
        error: const Color(0xFFCF6679),
        onError: Colors.black,
        surface: mediumSlate,
        onSurface: Colors.white,
        surfaceContainerHighest: mediumSlateLight,
        surfaceContainerHigh: mediumSlateLight,
        surfaceContainer: mediumSlate,
        surfaceContainerLow: mediumSlateDark,
        surfaceContainerLowest: mediumBackground,
        outline: Colors.white24,
        outlineVariant: Colors.white12,
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: Colors.white,
        onInverseSurface: Colors.black,
        inversePrimary: mediumAmber,
      ),
      scaffoldBackgroundColor: mediumBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: mediumSlate,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: mediumSlate,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12, width: 1),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.white12,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Colors.white70,
        textColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: mediumSlate,
        selectedItemColor: mediumAmber,
        unselectedItemColor: Colors.white38,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: mediumSlate,
        indicatorColor: mediumAmber.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        height: 60,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: mediumSlateLight,
        selectedColor: mediumAmber.withValues(alpha: 0.2),
        labelStyle: const TextStyle(color: Colors.white),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        side: const BorderSide(color: Colors.white12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: mediumSlate,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.syne(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: GoogleFonts.syne(
          color: Colors.white70,
          fontSize: 14,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: mediumSlateLight,
        contentTextStyle: GoogleFonts.syne(color: Colors.white),
        actionTextColor: mediumAmber,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
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
