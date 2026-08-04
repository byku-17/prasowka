import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/widgets/section_header.dart';

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('WYGLĄD I ALERTY')),
      body: ListView(
        children: [
          const SectionHeader('MOTYW'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Tryb jasny/ciemny'),
            subtitle: Text(_themeModeName(settings.themeMode)),
            onTap: () => _showThemePicker(context, settings),
          ),
          const SectionHeader('KOLORYSTYKA APLIKACJI'),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _ThemeVariantTile(
                  variant: AppThemeVariant.classic,
                  label: 'Sowa Classic',
                  primary: AppTheme.primaryNavy,
                  accent: AppTheme.accentGold,
                  isSelected: settings.themeVariant == AppThemeVariant.classic,
                  onTap: () => settings.setThemeVariant(AppThemeVariant.classic),
                ),
                _ThemeVariantTile(
                  variant: AppThemeVariant.elegantLight,
                  label: 'Elegant Light',
                  primary: AppTheme.elegantGold,
                  accent: AppTheme.elegantEcru,
                  isSelected: settings.themeVariant == AppThemeVariant.elegantLight,
                  onTap: () => settings.setThemeVariant(AppThemeVariant.elegantLight),
                ),
                _ThemeVariantTile(
                  variant: AppThemeVariant.royalPurple,
                  label: 'Royal Purple',
                  primary: AppTheme.royalPurple,
                  accent: Colors.white,
                  isSelected: settings.themeVariant == AppThemeVariant.royalPurple,
                  onTap: () => settings.setThemeVariant(AppThemeVariant.royalPurple),
                ),
                _ThemeVariantTile(
                  variant: AppThemeVariant.medium,
                  label: 'Medium Slate',
                  primary: AppTheme.mediumSlate,
                  accent: AppTheme.mediumAmber,
                  isSelected: settings.themeVariant == AppThemeVariant.medium,
                  onTap: () => settings.setThemeVariant(AppThemeVariant.medium),
                ),
                _ThemeVariantTile(
                  variant: AppThemeVariant.system,
                  label: 'Automatyczny',
                  primary: Colors.grey,
                  accent: Colors.blueGrey,
                  isSystem: true,
                  isSelected: settings.themeVariant == AppThemeVariant.system,
                  onTap: () => settings.setThemeVariant(AppThemeVariant.system),
                ),
              ],
            ),
          ),
          const Divider(),
          const SectionHeader('POWIADOMIENIA (WARTOWNIK SOWY)'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Powiadamiaj o ważnych tematach'),
            subtitle: const Text('Sowa będzie szukać newsów w tle i da znać o tych, które pasują do Twoich polubień.'),
            value: settings.notificationsEnabled,
            onChanged: (val) => settings.toggleNotifications(val),
            activeThumbColor: AppTheme.accentGold,
          ),
          const SectionHeader('WIDOK SPORTOWY'),
          SwitchListTile(
            secondary: const Icon(Icons.sports_score_outlined),
            title: const Text('Pokaż wyniki meczów'),
            subtitle: const Text('Wyświetla pasek z wynikami na górze sekcji Sport.'),
            value: settings.showSportsBar,
            onChanged: (val) => settings.toggleSportsBar(val),
            activeThumbColor: AppTheme.accentGold,
          ),
          if (settings.showSportsBar)
            SwitchListTile(
              title: const Text('Tylko moi faworyci', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Pokazuje wyłącznie mecze klubów i lig wpisanych w zainteresowaniach.', style: TextStyle(fontSize: 11)),
              value: settings.onlyFavoriteTeams,
              onChanged: (val) => settings.setOnlyFavoriteTeams(val),
              activeThumbColor: AppTheme.accentGold,
              dense: true,
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Wyczyść pamięć cache'),
            subtitle: const Text('Usuwa pobrane wcześniej artykuły i obrazy.'),
            onTap: () async {
              await settings.clearNewsCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache wyczyszczony.')));
              }
            },
          ),
        ],
      ),
    );
  }

  String _themeModeName(ThemeMode mode) {
    switch (mode) { case ThemeMode.system: return 'Systemowy'; case ThemeMode.light: return 'Jasny'; case ThemeMode.dark: return 'Ciemny'; }
  }

  void _showThemePicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(context: context, builder: (context) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.brightness_auto), title: const Text('Systemowy'), onTap: () { settings.setThemeMode(ThemeMode.system); Navigator.pop(context); }),
      ListTile(leading: const Icon(Icons.light_mode), title: const Text('Jasny'), onTap: () { settings.setThemeMode(ThemeMode.light); Navigator.pop(context); }),
      ListTile(leading: const Icon(Icons.dark_mode), title: const Text('Ciemny'), onTap: () { settings.setThemeMode(ThemeMode.dark); Navigator.pop(context); }),
      ])));
  }
}

class _ThemeVariantTile extends StatelessWidget {
  final AppThemeVariant variant;
  final String label;
  final Color primary;
  final Color accent;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isSystem;

  const _ThemeVariantTile({
    required this.variant,
    required this.label,
    required this.primary,
    required this.accent,
    required this.isSelected,
    required this.onTap,
    this.isSystem = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppTheme.accentGold : Colors.transparent,
                  width: 3,
                ),
                gradient: isSystem ? null : LinearGradient(
                  colors: [primary, accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                color: isSystem ? Colors.grey.withValues(alpha: 0.1) : null,
              ),
              child: isSystem ? const Icon(Icons.auto_fix_high, size: 24) : (isSelected ? const Icon(Icons.check, color: Colors.white) : null),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.accentGold : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
