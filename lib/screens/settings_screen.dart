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
            subtitle: 'Motyw, alerty Sowy, pamięć cache',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AppearanceSettingsPage())),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.category_outlined,
            title: 'Zarządzanie Kategoriami',
            subtitle: 'Aktywne zakładki, kolejność wyświetlania',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _CategorySettingsPage())),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.rss_feed,
            title: 'Zarządzanie Źródłami',
            subtitle: 'Włączanie portali, własne kanały RSS',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _SourceSettingsPage())),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.psychology_outlined,
            title: 'Moje Zainteresowania',
            subtitle: 'Słowa kluczowe, ulubione drużyny i tematy',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _InterestsSettingsPage())),
          ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('INFORMACJE', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentGold, fontSize: 12, letterSpacing: 1.2)),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Prasówka v1.1.0'),
            subtitle: Text('Z inteligentnym silnikiem rekomendacji'),
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
class _AppearanceSettingsPage extends StatelessWidget {
  const _AppearanceSettingsPage();

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
          if (settings.notificationsEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextButton.icon(
                onPressed: () => BackgroundService().showTestNotification(),
                icon: const Icon(Icons.notification_important, size: 18),
                label: const Text('WYŚLIJ TESTOWY ALERT', style: TextStyle(fontSize: 11)),
              ),
            ),
          const _SectionHeader('SPORT'),
          SwitchListTile(
            secondary: const Icon(Icons.sports_score_outlined),
            title: const Text('Pokaż wyniki meczów'),
            subtitle: const Text('Wyświetla pasek z wynikami na żywo dla Twoich ulubionych drużyn i lig.'),
            value: settings.showSportsBar,
            onChanged: (val) => settings.toggleSportsBar(val),
            activeColor: AppTheme.accentGold,
          ),
          if (settings.showSportsBar) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('WŁĄCZONE DYSCYPLINY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            _buildSportToggles(settings),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Tylko moje drużyny', style: TextStyle(fontSize: 14)),
              subtitle: const Text('Pokazuje tylko mecze klubów wpisanych w zainteresowaniach.', style: TextStyle(fontSize: 11)),
              value: settings.onlyFavoriteTeams,
              onChanged: (val) => settings.setOnlyFavoriteTeams(val),
              activeColor: AppTheme.accentGold,
              dense: true,
            ),
            ListTile(
              title: const Text('Zarządzaj ligami piłkarskimi', style: TextStyle(fontSize: 14)),
              subtitle: Text('${settings.enabledLeagues.length} wybranych lig', style: const TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => _showLeaguePicker(context, settings),
              dense: true,
            ),
          ],
          const Divider(),
          const _SectionHeader('SYSTEMOWE'),
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

  Widget _buildSportToggles(SettingsProvider settings) {
    final sports = ['football', 'nba', 'f1', 'tennis', 'volleyball', 'handball', 'nhl', 'mlb', 'nfl'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Wrap(
        spacing: 8,
        children: sports.map((s) => FilterChip(
          label: Text(_sportName(s), style: const TextStyle(fontSize: 10)),
          selected: settings.enabledSports.contains(s),
          onSelected: (_) => settings.toggleSport(s),
          selectedColor: AppTheme.accentGold.withValues(alpha: 0.3),
          checkmarkColor: AppTheme.accentGold,
        )).toList(),
      ),
    );
  }

  String _sportName(String id) {
    switch (id) {
      case 'football': return 'Piłka Nożna';
      case 'ekstraklasa': return 'Ekstraklasa';
      case 'nba': return 'NBA';
      case 'f1': return 'F1';
      case 'tennis': return 'Tenis';
      case 'volleyball': return 'Siatkówka';
      case 'handball': return 'Piłka Ręczna';
      case 'nhl': return 'NHL';
      case 'mlb': return 'MLB';
      case 'nfl': return 'NFL';
      default: return id.toUpperCase();
    }
  }

  void _showThemePicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(context: context, builder: (context) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.brightness_auto), title: const Text('Systemowy'), onTap: () { settings.setThemeMode(ThemeMode.system); Navigator.pop(context); }),
      ListTile(leading: const Icon(Icons.light_mode), title: const Text('Jasny'), onTap: () { settings.setThemeMode(ThemeMode.light); Navigator.pop(context); }),
      ListTile(leading: const Icon(Icons.dark_mode), title: const Text('Ciemny'), onTap: () { settings.setThemeMode(ThemeMode.dark); Navigator.pop(context); }),
    ])));
  }

  void _showLeaguePicker(BuildContext context, SettingsProvider settings) {
    final leagues = [
      {'name': 'PKO BP Ekstraklasa (Polska)', 'code': 'EKSTRAKLASA'},
      {'name': 'Premier League (Anglia)', 'code': 'PL'},
      {'name': 'La Liga (Hiszpania)', 'code': 'PD'},
      {'name': 'Bundesliga (Niemcy)', 'code': 'BL1'},
      {'name': 'Serie A (Włochy)', 'code': 'SA'},
      {'name': 'Ligue 1 (Francja)', 'code': 'FL1'},
      {'name': 'Champions League (Europa)', 'code': 'CL'},
      {'name': 'Eredivisie (Holandia)', 'code': 'DED'},
      {'name': 'Primeira Liga (Portugalia)', 'code': 'PPL'},
      {'name': 'Championship (Anglia)', 'code': 'ELC'},
      {'name': 'Euro 2024', 'code': 'EC'},
      {'name': 'Mistrzostwa Świata', 'code': 'WC'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const Text('WYBIERZ LIGI PIŁKARSKIE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: leagues.length,
                      itemBuilder: (context, index) {
                        final l = leagues[index];
                        final isEnabled = settings.enabledLeagues.contains(l['code']);
                        return CheckboxListTile(
                          title: Text(l['name']!, style: const TextStyle(fontSize: 14)),
                          value: isEnabled,
                          activeColor: AppTheme.accentGold,
                          onChanged: (_) {
                            settings.toggleLeague(l['code']!);
                            setModalState(() {});
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// --- PODSTRONA: ZARZĄDZANIE KATEGORIAMI ---
class _CategorySettingsPage extends StatelessWidget {
  const _CategorySettingsPage();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('KATEGORIE')),
      body: ListView(
        children: [
          const _SectionHeader('AKTYWNE ZAKŁADKI'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('Zaznacz kategorie, które mają pojawiać się na górnym pasku.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          ...NewsCategory.defaultCategories.where((c) => c.id != 'all').map((cat) => CheckboxListTile(
            title: Text(cat.name),
            secondary: Icon(cat.icon),
            value: settings.isCategoryActive(cat.id),
            onChanged: (_) => settings.toggleCategory(cat.id),
            activeColor: AppTheme.accentGold,
          )),
          const Divider(),
          const _SectionHeader('KOLEJNOŚĆ (PRZECIĄGNIJ)'),
          SizedBox(
            height: 400,
            child: ReorderableListView(
              onReorder: (oldIndex, newIndex) => settings.reorderCategories(oldIndex, newIndex),
              children: settings.allCategoriesOrdered.map((cat) => ListTile(
                key: ValueKey(cat.id),
                leading: const Icon(Icons.drag_handle, color: Colors.grey),
                title: Text(cat.name),
                trailing: Icon(cat.icon, size: 18, color: AppTheme.accentGold.withValues(alpha: 0.5)),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// --- PODSTRONA: ZARZĄDZANIE ŹRÓDŁAMI ---
class _SourceSettingsPage extends StatelessWidget {
  const _SourceSettingsPage();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ŹRÓDŁA RSS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddSourceDialog(context, settings),
            tooltip: 'Dodaj RSS',
          )
        ],
      ),
      body: ListView(
        children: [
          // SZYBKIE AKCJE
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => settings.toggleAllSources(true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentGold, foregroundColor: Colors.black),
                    child: const Text('WŁĄCZ WSZYSTKO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => settings.toggleAllSources(false),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900], foregroundColor: Colors.white),
                    child: const Text('WYŁĄCZ WSZYSTKO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          ...NewsCategory.defaultCategories.where((c) => c.id != 'all').map((cat) {
            final sourcesInCategory = settings.allSources.where((s) => s.categoryId == cat.id).toList();
            if (sourcesInCategory.isEmpty) return const SizedBox.shrink();
            return _buildCategoryGroup(context, cat, sourcesInCategory, settings);
          }),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: OutlinedButton.icon(
              onPressed: () => _showResetConfirm(context, settings),
              icon: const Icon(Icons.restore),
              label: const Text('PRZYWRÓĆ DOMYŚLNE ŹRÓDŁA', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCategoryGroup(BuildContext context, NewsCategory category, List<NewsSource> sources, SettingsProvider settings) {
    final allActive = sources.every((s) => settings.isSourceActive(s.id));
    return ExpansionTile(
      leading: Icon(category.icon, color: AppTheme.accentGold, size: 20),
      title: Text(category.name.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      subtitle: Text('${sources.where((s) => settings.isSourceActive(s.id)).length} / ${sources.length} aktywnych', style: const TextStyle(fontSize: 10)),
      trailing: TextButton(
        child: Text(allActive ? 'WYŁĄCZ' : 'WŁĄCZ', style: TextStyle(fontSize: 10, color: allActive ? Colors.red : AppTheme.accentGold)),
        onPressed: () => settings.toggleAllSourcesInCategory(category.id, !allActive),
      ),
      children: sources.map((src) => ListTile(
        title: Text(src.name, style: const TextStyle(fontSize: 14)),
        leading: Switch(
          value: settings.isSourceActive(src.id),
          onChanged: (_) => settings.toggleSource(src.id),
          activeColor: AppTheme.accentGold,
        ),
        trailing: src.id.startsWith('custom_') ? IconButton(
          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
          onPressed: () => settings.deleteSource(src.id),
        ) : null,
        dense: true,
      )).toList(),
    );
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
      content: const Text('Wszystkie Twoje własne źródła zostaną usunięte, a lista portali zostanie zresetowana.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANULUJ')),
        TextButton(onPressed: () { settings.resetToDefaultSources(); Navigator.pop(context); }, child: const Text('PRZYWRÓĆ', style: TextStyle(color: Colors.red))),
      ],
    ));
  }
}

// --- PODSTRONA: MOJE ZAINTERESOWANIA ---
class _InterestsSettingsPage extends StatefulWidget {
  const _InterestsSettingsPage();

  @override
  State<_InterestsSettingsPage> createState() => _InterestsSettingsPageState();
}

class _InterestsSettingsPageState extends State<_InterestsSettingsPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(SettingsProvider settings) {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      if (settings.favoriteTeams.any((e) => e.toLowerCase() == text.toLowerCase())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('To hasło jest już na liście.')),
        );
        return;
      }
      settings.addKeyword(text);
      _controller.clear();
      // Usunięto FocusScope.of(context).unfocus(), aby móc dodawać seryjnie
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('ZAINTERESOWANIA')),
      body: ListView(
        children: [
          const _SectionHeader('TEMATY I SŁOWA KLUCZOWE'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sowa analizuje te tematy i promuje powiązane artykuły na Twojej liście. Możesz tu dodać dowolne hasła, np. "Iga Świątek", "Tesla" czy "Giełda".',
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
          const _SectionHeader('EDYCJA WYBORU STARTOWEGO'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Możesz tu zmienić tematy, które wybrałeś podczas pierwszego uruchomienia aplikacji.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          const SizedBox(height: 16),
          ...settings.activeCategories.map((cat) => ListTile(
            leading: Icon(cat.icon, size: 18),
            title: Text(cat.name),
            trailing: const Icon(Icons.check, color: AppTheme.accentGold, size: 16),
            dense: true,
          )),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _CategorySettingsPage())),
              child: const Text('ZARZĄDZAJ KATEGORIAMI', style: TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold)),
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
