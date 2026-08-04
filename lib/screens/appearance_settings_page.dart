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
    final currentVariant = settings.themeVariant;
    final currentMode = settings.themeMode;

    // Określ aktualną opcję na podstawie wariantu + trybu
    String currentLabel = _getCurrentLabel(currentVariant, currentMode);

    return Scaffold(
      appBar: AppBar(title: const Text('WYGLĄD I ALERTY')),
      body: ListView(
        children: [
          const SectionHeader('MOTYW'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Tryb wyświetlania'),
            subtitle: Text(currentLabel),
            onTap: () => _showUnifiedThemePicker(context, settings),
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

  String _getCurrentLabel(AppThemeVariant variant, ThemeMode mode) {
    if (mode == ThemeMode.system) return 'Systemowy';
    switch (variant) {
      case AppThemeVariant.classic:
        return mode == ThemeMode.dark ? 'Ciemny' : 'Jasny';
      case AppThemeVariant.medium:
      case AppThemeVariant.royalPurple:
        return 'Medium (fioletowy)';
      case AppThemeVariant.elegantLight:
        return 'Jasny';
      default:
        return 'Systemowy';
    }
  }

  void _showUnifiedThemePicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Wybierz motyw', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            _buildOption(
              context: context,
              icon: Icons.light_mode,
              label: 'Jasny',
              isSelected: settings.themeMode == ThemeMode.light && settings.themeVariant == AppThemeVariant.classic,
              onTap: () {
                settings.setThemeVariant(AppThemeVariant.classic);
                settings.setThemeMode(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            _buildOption(
              context: context,
              icon: Icons.invert_colors_on,
              label: 'Medium (fioletowy)',
              isSelected: settings.themeVariant == AppThemeVariant.medium || settings.themeVariant == AppThemeVariant.royalPurple,
              onTap: () {
                settings.setThemeVariant(AppThemeVariant.medium);
                settings.setThemeMode(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            _buildOption(
              context: context,
              icon: Icons.dark_mode,
              label: 'Ciemny',
              isSelected: settings.themeMode == ThemeMode.dark && settings.themeVariant == AppThemeVariant.classic,
              onTap: () {
                settings.setThemeVariant(AppThemeVariant.classic);
                settings.setThemeMode(ThemeMode.dark);
                Navigator.pop(context);
              },
            ),
            _buildOption(
              context: context,
              icon: Icons.brightness_auto,
              label: 'Systemowy',
              isSelected: settings.themeMode == ThemeMode.system,
              onTap: () {
                settings.setThemeVariant(AppThemeVariant.system);
                settings.setThemeMode(ThemeMode.system);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.accentGold : null),
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check, color: AppTheme.accentGold) : null,
      onTap: onTap,
    );
  }
}
