import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/news_source.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/settings_provider.dart';
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
            trailing: Text('1.2.0 (V4.2 Clean)', style: TextStyle(color: Colors.grey, fontSize: 12)),
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

// --- PODSTRONA: WYGLĄD I POWIADOMIENIA ---
class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('WYGLĄD I ALERTY')),
      body: ListView(
        children: [
          const _SectionHeader('MOTYW'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Tryb wyglądu'),
            subtitle: Text(_themeModeName(settings.themeMode)),
            onTap: () => _showThemePicker(context, settings),
          ),
          const Divider(),
          const _SectionHeader('POWIADOMIENIA (WARTOWNIK SOWY)'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Powiadamiaj o ważnych tematach'),
            subtitle: const Text('Sowa będzie szukać newsów w tle i da znać o tych, które pasują do Twoich polubień.'),
            value: settings.notificationsEnabled,
            onChanged: (val) => settings.toggleNotifications(val),
            activeColor: AppTheme.accentGold,
          ),
          const _SectionHeader('WIDOK SPORTOWY'),
          SwitchListTile(
            secondary: const Icon(Icons.sports_score_outlined),
            title: const Text('Pokaż wyniki meczów'),
            subtitle: const Text('Wyświetla pasek z wynikami na górze sekcji Sport.'),
            value: settings.showSportsBar,
            onChanged: (val) => settings.toggleSportsBar(val),
            activeColor: AppTheme.accentGold,
          ),
          if (settings.showSportsBar)
            SwitchListTile(
              title: const Text('Tylko moi faworyci', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Pokazuje wyłącznie mecze klubów i lig wpisanych w zainteresowaniach.', style: TextStyle(fontSize: 11)),
              value: settings.onlyFavoriteTeams,
              onChanged: (val) => settings.setOnlyFavoriteTeams(val),
              activeColor: AppTheme.accentGold,
              dense: true,
            ),
          const Divider(),
          const _SectionHeader('TWOJE MIASTO'),
          ListTile(
            leading: const Icon(Icons.location_city),
            title: const Text('Miasto'),
            subtitle: Text(settings.preferredCity),
            onTap: () => _showCityPicker(context, settings),
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

  void _showCityPicker(BuildContext context, SettingsProvider settings) {
    final cities = [
      {'name': 'Warszawa', 'lat': 52.2297, 'lon': 21.0122},
      {'name': 'Kraków', 'lat': 50.0647, 'lon': 19.9450},
      {'name': 'Wrocław', 'lat': 51.1079, 'lon': 17.0385},
      {'name': 'Gdańsk', 'lat': 54.3520, 'lon': 18.6466},
      {'name': 'Poznań', 'lat': 52.4064, 'lon': 16.9252},
      {'name': 'Łódź', 'lat': 51.7592, 'lon': 19.4560},
      {'name': 'Katowice', 'lat': 50.2649, 'lon': 19.0238},
    ];
    showModalBottomSheet(context: context, builder: (context) => SafeArea(child: ListView(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Wybierz miasto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        ...cities.map((c) => ListTile(
          leading: Icon(
            Icons.location_on,
            color: settings.preferredCity == c['name'] ? AppTheme.accentGold : null,
          ),
          title: Text(c['name'] as String),
          trailing: settings.preferredCity == c['name'] ? const Icon(Icons.check, color: AppTheme.accentGold) : null,
          onTap: () {
            settings.setPreferredCity(c['name'] as String, c['lat'] as double, c['lon'] as double);
            Navigator.pop(context);
          },
        )),
      ],
    )));
  }
}

// --- PODSTRONA: ZARZĄDZANIE KATEGORIAMI ---
class CategorySettingsPage extends StatelessWidget {
  const CategorySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('KATEGORIE')),
      body: ReorderableListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        onReorder: (oldIndex, newIndex) => settings.reorderCategories(oldIndex, newIndex),
        children: settings.allCategoriesOrdered.map((cat) {
          final isActive = settings.isCategoryActive(cat.id);
          return ListTile(
            key: ValueKey(cat.id),
            leading: Icon(cat.icon, color: isActive ? AppTheme.accentGold : Colors.grey),
            title: Text(cat.name, style: TextStyle(color: isActive ? Colors.white : Colors.grey)),
            trailing: cat.id == 'all' 
                ? const Icon(Icons.lock_outline, size: 18, color: Colors.grey)
                : Switch(
                    value: isActive,
                    onChanged: (_) => settings.toggleCategory(cat.id),
                    activeColor: AppTheme.accentGold,
                  ),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context, settings),
        backgroundColor: AppTheme.accentGold,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('NOWA KATEGORIA'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nazwa (np. AI, Finanse)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANULUJ')),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                settings.addCustomCategory(controller.text, Icons.star_border);
                Navigator.pop(context);
              }
            },
            child: const Text('DODAJ', style: TextStyle(color: AppTheme.accentGold)),
          ),
        ],
      ),
    );
  }
}

// --- PODSTRONA: ZARZĄDZANIE ŹRÓDŁAMI ---
class SourceSettingsPage extends StatelessWidget {
  const SourceSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final categories = settings.allCategories.where((c) => c.id != 'all').toList();
    final city = settings.preferredCity;

    return Scaffold(
      appBar: AppBar(title: const Text('PORTALE I RSS')),
      body: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          var sources = settings.allSources.where((s) => s.categoryId == cat.id).toList();
          
          // Dla kategorii "warsaw" podmień źródła na dynamiczne miasto
          if (cat.id == 'warsaw' && city.toLowerCase() != 'warszawa') {
            sources = [
              NewsSource(
                id: 'dynamic_city_${city.toLowerCase()}',
                name: 'Google News: $city',
                rssUrl: 'https://news.google.com/rss/search?q=${Uri.encodeComponent(city)}&hl=pl&gl=PL&ceid=PL:pl',
                categoryId: 'warsaw',
              ),
            ];
          }
          
          if (sources.isEmpty) return const SizedBox.shrink();

          final displayName = cat.id == 'warsaw' ? city : cat.name;

          return ExpansionTile(
            leading: Icon(cat.icon, color: AppTheme.accentGold, size: 20),
            title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            children: sources.map((src) => CheckboxListTile(
              title: Text(src.name, style: const TextStyle(fontSize: 13)),
              subtitle: Text(src.rssUrl, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
              value: settings.isSourceActive(src.id),
              activeColor: AppTheme.accentGold,
              onChanged: (_) => settings.toggleSource(src.id),
            )).toList(),
          );
        },
      ),
    );
  }
}

// --- PODSTRONA: MOJE ZAINTERESOWANIA ---
class InterestsSettingsPage extends StatefulWidget {
  const InterestsSettingsPage({super.key});

  @override
  State<InterestsSettingsPage> createState() => InterestsSettingsPageState();
}

class InterestsSettingsPageState extends State<InterestsSettingsPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(SettingsProvider settings) {
    if (_controller.text.isNotEmpty) {
      settings.addKeyword(_controller.text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('MOJE TEMATY')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader('TEMATY, DRUŻYNY I LIGI'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wpisz nazwę klubu lub ligi (np. "Legia", "Ekstraklasa", "NBA"), aby śledzić wyniki na żywo w zakładce Sport oraz otrzymywać spersonalizowane newsy.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 0,
                  children: settings.favoriteTeams.map((team) => Chip(
                    label: Text(team),
                    onDeleted: () => settings.removeKeyword(team),
                    deleteIconColor: Colors.red,
                    backgroundColor: AppTheme.accentGold.withValues(alpha: 0.1),
                    side: const BorderSide(color: AppTheme.accentGold),
                  )).toList(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Dodaj nowe hasło...',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_circle, color: AppTheme.accentGold),
                      onPressed: () => _submit(settings),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _submit(settings),
                ),
              ],
            ),
          ),
          const Divider(height: 40),
          const _SectionHeader('PODPOWIEDZI'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Możesz tu dodać dowolne hasła, np. "Iga Świątek", "Tesla", "Górnik Zabrze" czy "Giełda". Sowa automatycznie przefiltruje dla Ciebie internet.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentGold, letterSpacing: 1.2, fontSize: 12),
      ),
    );
  }
}
