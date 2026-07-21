import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';
import '../models/news_category.dart';
import '../models/news_source.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('USTAWIENIA'),
      ),
      body: ListView(
        children: [
          _buildHeader('MOTYW'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Tryb wyglądu'),
            subtitle: Text(_themeModeName(settings.themeMode)),
            onTap: () => _showThemePicker(context, settings),
          ),
          
          const Divider(),
          _buildHeader('AKTYWNE KATEGORIE'),
          ...NewsCategory.defaultCategories.where((c) => c.id != 'all').map((cat) => CheckboxListTile(
            title: Text(cat.name),
            secondary: Icon(cat.icon),
            value: settings.isCategoryActive(cat.id),
            onChanged: (_) => settings.toggleCategory(cat.id),
            activeColor: AppTheme.accentGold,
          )),

          const Divider(),
          _buildHeader('MOJE ZAINTERESOWANIA SPORTOWE'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sowa będzie wyłapywać wiadomości o tych drużynach/zawodnikach i pokazywać je na górze sekcji Sport.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: settings.favoriteTeams.map((team) => Chip(
                    label: Text(team),
                    onDeleted: () => settings.removeTeam(team),
                    deleteIconColor: Colors.red,
                    backgroundColor: AppTheme.accentGold.withOpacity(0.1),
                  )).toList(),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Dodaj drużynę (np. Lakers, Legia...)',
                    suffixIcon: Icon(Icons.add),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      settings.addTeam(value);
                    }
                  },
                ),
              ],
            ),
          ),

          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeader('ŹRÓDŁA WIADOMOŚCI'),
              Padding(
                padding: const EdgeInsets.only(right: 16.0, top: 16.0),
                child: TextButton.icon(
                  icon: const Icon(Icons.select_all, size: 18),
                  label: const Text('WSZYSTKO'),
                  onPressed: () => _showGlobalToggle(context, settings),
                ),
              ),
            ],
          ),
          
          // Grupowanie źródeł wg kategorii
          ...NewsCategory.defaultCategories.where((c) => c.id != 'all').map((cat) {
            final sourcesInCategory = NewsSource.defaultSources.where((s) => s.categoryId == cat.id).toList();
            if (sourcesInCategory.isEmpty) return const SizedBox.shrink();
            
            return _buildCategorySourceGroup(context, cat, sourcesInCategory, settings);
          }),

          const Divider(),
          _buildHeader('INFORMACJE'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('O aplikacji'),
            subtitle: Text('Prasówka v1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Autor'),
            subtitle: Text('Zbudowano z pomocą AI'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCategorySourceGroup(BuildContext context, NewsCategory category, List<NewsSource> sources, SettingsProvider settings) {
    final allActive = sources.every((s) => settings.isSourceActive(s.id));
    
    return ExpansionTile(
      leading: Icon(category.icon, color: AppTheme.accentGold, size: 20),
      title: Text(category.name.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      trailing: TextButton(
        child: Text(allActive ? 'WYŁĄCZ' : 'WŁĄCZ'),
        onPressed: () => settings.toggleAllSourcesInCategory(category.id, !allActive),
      ),
      children: sources.map((src) => SwitchListTile(
        title: Text(src.name, style: const TextStyle(fontSize: 14)),
        value: settings.isSourceActive(src.id),
        onChanged: (_) => settings.toggleSource(src.id),
        activeColor: AppTheme.accentGold,
        dense: true,
      )).toList(),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppTheme.accentGold,
          letterSpacing: 1.2,
          fontSize: 12,
        ),
      ),
    );
  }

  String _themeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system: return 'Systemowy';
      case ThemeMode.light: return 'Jasny';
      case ThemeMode.dark: return 'Ciemny';
    }
  }

  void _showThemePicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: const Text('Systemowy'),
              onTap: () {
                settings.setThemeMode(ThemeMode.system);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: const Text('Jasny'),
              onTap: () {
                settings.setThemeMode(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Ciemny'),
              onTap: () {
                settings.setThemeMode(ThemeMode.dark);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showGlobalToggle(BuildContext context, SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Masowe zarządzanie'),
        content: const Text('Czy chcesz włączyć lub wyłączyć wszystkie źródła wiadomości naraz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANULUJ')),
          TextButton(onPressed: () { settings.toggleAllSources(false); Navigator.pop(context); }, child: const Text('WYŁĄCZ WSZYSTKO')),
          TextButton(onPressed: () { settings.toggleAllSources(true); Navigator.pop(context); }, child: const Text('WŁĄCZ WSZYSTKO')),
        ],
      ),
    );
  }
}
