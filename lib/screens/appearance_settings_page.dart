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
      appBar: AppBar(title: const Text('WYGLĄD')),
      body: ListView(
        children: [
          const SectionHeader('MOTYW'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Tryb wyświetlania'),
            subtitle: Text(currentLabel),
            onTap: () => _showUnifiedThemePicker(context, settings),
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
      leading: Icon(icon, color: isSelected ? AppTheme.accentFor(context) : null),
      title: Text(label),
      trailing: isSelected ? Icon(Icons.check, color: AppTheme.accentFor(context)) : null,
      onTap: onTap,
    );
  }
}
