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
  static const Color royalPurple = Color(0xFF9B6DD7);
  static const Color royalPurpleDark = Color(0xFF8B5CF6);
  static const Color lightPurple = Color(0xFFE8DAFF);
  static const Color mediumPurple = Color(0xFF7C5CBF);
  static const Color mediumBg = Color(0xFFF3EEFF);
  static const Color mediumCard = Color(0xFFEDE5FF);

  /// Zwraca kolor akcentu dopasowany do aktualnego motywu
  static Color accentFor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return scheme.primary;
  }

  static ThemeData getTheme(AppThemeVariant variant, bool isDark, {ColorScheme? dynamicScheme}) {
    switch (variant) {
      case AppThemeVariant.elegantLight:
        return _buildElegantLightTheme();
      case AppThemeVariant.royalPurple:
        return isDark ? _buildRoyalDarkTheme() : _buildRoyalLightTheme();
      case AppThemeVariant.medium:
        return _buildMediumTheme();
      case AppThemeVariant.system:
        return isDark ? _buildClassicDarkTheme() : _buildClassicLightTheme();
      case AppThemeVariant.classic:
      default:
        return isDark ? _buildClassicDarkTheme() : _buildClassicLightTheme();
    }
  }

  // ─── CIEMNY: ciemne tło + złote/pomarańczowe akcenty ───

  static ThemeData _buildClassicDarkTheme() {
    const Color deepBlack = Color(0xFF1E2126);
    const Color surfaceDark = Color(0xFF262B32);
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
        foregroundColor: accentGold,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12, width: 1),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? accentGold : Colors.grey),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? accentGold.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentGold,
          foregroundColor: deepBlack,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentGold),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: accentGold),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentGold,
        foregroundColor: deepBlack,
      ),
      dividerTheme: const DividerThemeData(color: Colors.white12),
      iconTheme: const IconThemeData(color: Colors.white70),
      listTileTheme: const ListTileThemeData(
        textColor: Colors.white,
        iconColor: Colors.white70,
      ),
    );
  }

  // ─── JASNY: jasne tło + ciemne teksty ───

  static ThemeData _buildClassicLightTheme() {
    final base = ThemeData.light();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryNavy,
      textTheme: GoogleFonts.syneTextTheme(base.textTheme).apply(
        bodyColor: primaryNavy,
        displayColor: primaryNavy,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryNavy,
        primary: primaryNavy,
        secondary: accentGold,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F6F8),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F6F8),
        foregroundColor: primaryNavy,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE8E9EC), width: 1),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? primaryNavy : Colors.grey),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? primaryNavy.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryNavy),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: primaryNavy),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryNavy,
        foregroundColor: Colors.white,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE0E0E0)),
      iconTheme: const IconThemeData(color: Color(0xFF555555)),
      listTileTheme: const ListTileThemeData(
        textColor: primaryNavy,
        iconColor: Color(0xFF555555),
      ),
    );
  }

  // ─── ELEGANT: ecru + złoto ───

  static ThemeData _buildElegantLightTheme() {
    final base = ThemeData.light();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: elegantGold,
      textTheme: GoogleFonts.syneTextTheme(base.textTheme).apply(
        bodyColor: const Color(0xFF2C2C2C),
        displayColor: const Color(0xFF2C2C2C),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: elegantGold,
        primary: elegantGold,
        secondary: elegantGold,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: elegantEcru,
      appBarTheme: const AppBarTheme(
        backgroundColor: elegantEcru,
        foregroundColor: Color(0xFF2C2C2C),
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE8DCC8), width: 1),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? elegantGold : Colors.grey),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? elegantGold.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: elegantGold,
          foregroundColor: Colors.white,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: elegantGold),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: elegantGold),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFE8DCC8)),
      iconTheme: const IconThemeData(color: Color(0xFF666666)),
      listTileTheme: const ListTileThemeData(
        textColor: Color(0xFF2C2C2C),
        iconColor: Color(0xFF666666),
      ),
    );
  }

  // ─── ROYAL PURPLE LIGHT: fioletowe tło + ciemne teksty ───

  static ThemeData _buildRoyalLightTheme() {
    final base = ThemeData.light();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: royalPurple,
      textTheme: GoogleFonts.syneTextTheme(base.textTheme).apply(
        bodyColor: const Color(0xFF2D2D3F),
        displayColor: const Color(0xFF2D2D3F),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: royalPurple,
        primary: royalPurple,
        secondary: royalPurple,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F0FF),
      appBarTheme: const AppBarTheme(
        backgroundColor: royalPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFDCC8FF), width: 1),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? royalPurple : Colors.grey),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? royalPurple.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: royalPurple,
          foregroundColor: Colors.white,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: royalPurple),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: royalPurple),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: royalPurple,
        foregroundColor: Colors.white,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFDCC8FF)),
      iconTheme: const IconThemeData(color: Color(0xFF6B5B8D)),
      listTileTheme: const ListTileThemeData(
        textColor: Color(0xFF2D2D3F),
        iconColor: Color(0xFF6B5B8D),
      ),
    );
  }

  // ─── ROYAL PURPLE DARK: ciemne fioletowe tło + jasne teksty ───

  static ThemeData _buildRoyalDarkTheme() {
    const Color royalDarkBg = Color(0xFF1A1528);
    const Color royalDarkSurface = Color(0xFF241D36);
    final base = ThemeData.dark();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: royalPurpleDark,
      textTheme: GoogleFonts.syneTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: royalPurple,
        primary: royalPurple,
        secondary: lightPurple,
        surface: royalDarkBg,
      ),
      scaffoldBackgroundColor: royalDarkBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: royalDarkBg,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: royalDarkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Colors.white12),
      iconTheme: const IconThemeData(color: Colors.white70),
      listTileTheme: const ListTileThemeData(
        textColor: Colors.white,
        iconColor: Colors.white70,
      ),
    );
  }

  // ─── MEDIUM: fioletowe tło + ciemne teksty kontrastowe ───

  static ThemeData _buildMediumTheme() {
    final base = ThemeData.light();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: mediumPurple,
      textTheme: GoogleFonts.syneTextTheme(base.textTheme).apply(
        bodyColor: const Color(0xFF1E1B2E),
        displayColor: const Color(0xFF1E1B2E),
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: mediumPurple,
        primary: mediumPurple,
        secondary: mediumPurple,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: mediumBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: mediumPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: mediumCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: mediumPurple.withValues(alpha: 0.2), width: 1),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? mediumPurple : Colors.grey),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? mediumPurple.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mediumPurple,
          foregroundColor: Colors.white,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: mediumPurple),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: mediumPurple),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: mediumPurple,
        foregroundColor: Colors.white,
      ),
      dividerTheme: DividerThemeData(color: mediumPurple.withValues(alpha: 0.2)),
      iconTheme: IconThemeData(color: mediumPurple.withValues(alpha: 0.7)),
      listTileTheme: const ListTileThemeData(
        textColor: Color(0xFF1E1B2E),
        iconColor: Color(0xFF5A4A7A),
      ),
    );
  }
}
