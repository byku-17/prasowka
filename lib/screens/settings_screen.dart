import 'package:flutter/material.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/screens/appearance_settings_page.dart';
import 'package:prasowka/screens/category_settings_page.dart';
import 'package:prasowka/screens/city_sources_page.dart';
import 'package:prasowka/screens/source_settings_page.dart';
import 'package:prasowka/screens/interests_settings_page.dart';
import 'package:prasowka/screens/sport_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('USTAWIENIA'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSettingsTile(
            context,
            icon: Icons.palette_outlined,
            title: 'Wygląd i Powiadomienia',
            subtitle: 'Motyw, alerty Sowy, pasek sportowy',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppearanceSettingsPage())),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.category_outlined,
            title: 'Zarządzanie Kategoriami',
            subtitle: 'Aktywne zakładki, kolejność wyświetlania',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategorySettingsPage())),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.location_city,
            title: 'Miasto i Źródła',
            subtitle: 'Wybierz miasto, lokalne RSS',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CitySourcesPage())),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.rss_feed,
            title: 'Zarządzanie Źródłami',
            subtitle: 'Włączanie portali, własne kanały RSS',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SourceSettingsPage())),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.psychology_outlined,
            title: 'Moje Zainteresowania',
            subtitle: 'Kluby, ligi i tematy newsów',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InterestsSettingsPage())),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.sports_soccer_outlined,
            title: 'Moje Sporty',
            subtitle: 'Wybierz ligi do wyników na żywo',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SportSettingsScreen())),
          ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('INFORMACJE', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          const ListTile(
            title: Text('Wersja aplikacji'),
            trailing: Text('1.3.3 (V5.4 Intelligence)', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.accentGold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.accentGold),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
