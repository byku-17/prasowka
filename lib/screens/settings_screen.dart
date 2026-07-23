import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/models/news_category.dart';
import 'package:prasowka/models/news_source.dart';
import 'package:prasowka/services/background_service.dart';

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
          // GLOBALNE ZARZĄDZANIE
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentGold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accentGold.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ZARZĄDZANIE GLOBALNE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Text('Włącz lub wyłącz wszystkie źródła naraz', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => settings.toggleAllSources(true),
                  child: const Text('WŁĄCZ WSZYSTKO', style: TextStyle(fontSize: 11)),
                ),
                TextButton(
                  onPressed: () => settings.toggleAllSources(false),
                  child: const Text('WYŁĄCZ', style: TextStyle(fontSize: 11, color: Colors.red)),
                ),
              ],
            ),
          ),

          _buildHeader('MOTYW'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Tryb wyglądu'),
            subtitle: Text(_themeModeName(settings.themeMode)),
            onTap: () => _showThemePicker(context, settings),
          ),
          
          const Divider(),
          _buildHeader('POWIADOMIENIA (WARTOWNIK SOWY)'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Powiadamiaj o ważnych tematach'),
            subtitle: const Text('Sowa będzie szukać newsów w tle i da znać o tych, które pasują do Twoich polubień (wymaga internetu).'),
            value: settings.notificationsEnabled,
            onChanged: (val) => settings.toggleNotifications(val),
            activeColor: AppTheme.accentGold,
          ),
          if (settings.notificationsEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextButton.icon(
                onPressed: () => BackgroundService().showTestNotification(),
                icon: const Icon(Icons.notification_important, size: 18),
                label: const Text('WYŚLIJ TESTOWY ALERT', style: TextStyle(fontSize: 11)),
              ),
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
          _buildHeader('KOLEJNOŚĆ ZAKŁADEK (PRZECIĄGNIJ)'),
          SizedBox(
            height: 350,
            child: ReorderableListView(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              onReorder: (oldIndex, newIndex) => settings.reorderCategories(oldIndex, newIndex),
              children: settings.allCategoriesOrdered.map((cat) => ListTile(
                key: ValueKey(cat.id),
                leading: const Icon(Icons.drag_handle, color: Colors.grey),
                title: Text(cat.name),
                trailing: Icon(cat.icon, size: 18, color: AppTheme.accentGold.withValues(alpha: 0.5)),
              )).toList(),
            ),
          ),

          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeader('ZARZĄDZANIE ŹRÓDŁAMI'),
              Padding(
                padding: const EdgeInsets.only(right: 16, top: 16),
                child: TextButton.icon(
                  onPressed: () => _showAddSourceDialog(context, settings),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('DODAJ RSS', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
          
          ...NewsCategory.defaultCategories.where((c) => c.id != 'all').map((cat) {
            final sourcesInCategory = settings.allSources.where((s) => s.categoryId == cat.id).toList();
            if (sourcesInCategory.isEmpty) return const SizedBox.shrink();
            return _buildCategorySourceGroup(context, cat, sourcesInCategory, settings);
          }),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                  child: OutlinedButton.icon(
                    onPressed: () => _showResetConfirm(context, settings),
                    icon: const Icon(Icons.restore),
                    label: const Text('RESET ŹRÓDEŁ', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 16, 0),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await settings.clearNewsCache();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Pamięć cache została wyczyszczona.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.cleaning_services),
                    label: const Text('WYCZYŚĆ CACHE', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accentGold),
                  ),
                ),
              ),
            ],
          ),

          const Divider(),
          _buildHeader('MOJE ZAINTERESOWANIA SPORTOWE'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sowa będzie wyłapywać wiadomości o tych drużynach i pokazywać je na górze sekcji Sport.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: settings.favoriteTeams.map((team) => Chip(
                    label: Text(team),
                    onDeleted: () => settings.removeKeyword(team),
                    deleteIconColor: Colors.red,
                    backgroundColor: AppTheme.accentGold.withValues(alpha: 0.1),
                  )).toList(),
                ),
                TextField(
                  decoration: const InputDecoration(hintText: 'Dodaj drużynę...', suffixIcon: Icon(Icons.add)),
                  onSubmitted: (val) => val.isNotEmpty ? settings.addKeyword(val) : null,
                ),
              ],
            ),
          ),

          const Divider(),
          _buildHeader('INFORMACJE'),
          const ListTile(leading: Icon(Icons.info_outline), title: Text('Prasówka v1.1.0'), subtitle: Text('Z inteligentnym silnikiem rekomendacji')),
          const SizedBox(height: 60),
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
        child: Text(allActive ? 'WYŁĄCZ WSZYSTKO' : 'WŁĄCZ WSZYSTKO', style: TextStyle(fontSize: 10, color: allActive ? Colors.red : AppTheme.accentGold)),
        onPressed: () => settings.toggleAllSourcesInCategory(category.id, !allActive),
      ),
      children: sources.map((src) => ListTile(
        title: Text(src.name, style: const TextStyle(fontSize: 14)),
        leading: Switch(
          value: settings.isSourceActive(src.id),
          onChanged: (_) => settings.toggleSource(src.id),
          activeColor: AppTheme.accentGold,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
          onPressed: () => settings.deleteSource(src.id),
        ),
        dense: true,
      )).toList(),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 24, 16, 8), child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentGold, letterSpacing: 1.2, fontSize: 12)));
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

  void _showAddSourceDialog(BuildContext context, SettingsProvider settings) {
    String name = '';
    String url = '';
    String categoryId = NewsCategory.defaultCategories[1].id;

    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Dodaj własne źródło RSS'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(decoration: const InputDecoration(labelText: 'Nazwa serwisu'), onChanged: (v) => name = v),
        TextField(decoration: const InputDecoration(labelText: 'URL kanału RSS'), onChanged: (v) => url = v),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: categoryId,
          decoration: const InputDecoration(labelText: 'Kategoria'),
          items: NewsCategory.defaultCategories.where((c) => c.id != 'all').map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
          onChanged: (v) => categoryId = v!,
        ),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANULUJ')),
        ElevatedButton(onPressed: () {
          if (name.isNotEmpty && url.isNotEmpty) {
            settings.addCustomSource(NewsSource(id: 'custom_${DateTime.now().millisecondsSinceEpoch}', name: name, rssUrl: url, categoryId: categoryId));
            Navigator.pop(context);
          }
        }, child: const Text('DODAJ')),
      ],
    ));
  }

  void _showResetConfirm(BuildContext context, SettingsProvider settings) {
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text('Przywrócić domyślne?'),
      content: const Text('Wszystkie Twoje własne źródła zostaną usunięte, a lista 130 portali zostanie przywrócona do stanu fabrycznego.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANULUJ')),
        TextButton(onPressed: () { settings.resetToDefaultSources(); Navigator.pop(context); }, child: const Text('PRZYWRÓĆ', style: TextStyle(color: Colors.red))),
      ],
    ));
  }
}
