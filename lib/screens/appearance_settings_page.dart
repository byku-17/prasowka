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
            title: const Text('Tryb wyglądu'),
            subtitle: Text(_themeModeName(settings.themeMode)),
            onTap: () => _showThemePicker(context, settings),
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
