import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/screens/appearance_settings_page.dart';
import 'package:prasowka/screens/notification_settings_page.dart';
import 'package:prasowka/screens/category_settings_page.dart';
import 'package:prasowka/screens/source_settings_page.dart';
import 'package:prasowka/screens/interests_settings_page.dart';
import 'package:prasowka/screens/tag_settings_page.dart';
import 'package:prasowka/screens/sport_settings_page.dart';
import 'package:prasowka/screens/about_page.dart';
import 'package:prasowka/screens/auth_screen.dart';
import 'package:prasowka/services/auth_service.dart';
import 'package:prasowka/services/sync_service.dart';
import 'package:prasowka/providers/settings_provider.dart';

class _SettingsItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String section;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.section,
    required this.onTap,
  });
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── SEKCJA KONTO ───

  List<_SettingsItem> _buildAccountItems(AuthService auth, SyncService sync) {
    final items = <_SettingsItem>[];
    if (auth.isLoggedIn) {
      items.add(_SettingsItem(
        icon: Icons.sync,
        title: 'Synchronizuj dane',
        subtitle: sync.lastSync != null ? 'Ostatni sync: ${_formatTime(sync.lastSync!)}' : 'Nigdy nie synchronizowano',
        section: 'Konto',
        onTap: () async {
          await sync.pushAll();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Dane wysłane do chmury')),
            );
          }
        },
      ));
      items.add(_SettingsItem(
        icon: Icons.cloud_download,
        title: 'Pobierz z chmury',
        subtitle: 'Przywróć dane z innego urządzenia',
        section: 'Konto',
        onTap: () async {
          await sync.pullAll();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Dane pobrane z chmury — uruchom ponownie')),
            );
          }
        },
      ));
      items.add(_SettingsItem(
        icon: Icons.logout,
        title: 'Wyloguj się',
        subtitle: auth.user?.email ?? 'Konto Google',
        section: 'Konto',
        onTap: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Wylogować się?'),
              content: const Text('Dane lokalne pozostaną na urządzeniu.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Wyloguj')),
              ],
            ),
          );
          if (confirmed == true && context.mounted) {
            await auth.signOut();
          }
        },
      ));
    } else {
      items.add(_SettingsItem(
        icon: Icons.login,
        title: 'Zaloguj się / Zarejestruj',
        subtitle: 'Sync danych między urządzeniami',
        section: 'Konto',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen())),
      ));
    }
    return items;
  }

  // ─── SEKCJA WYGLĄD ───

  String _themeLabel(SettingsProvider settings) {
    if (settings.themeMode == ThemeMode.system) return 'Systemowy';
    switch (settings.themeVariant) {
      case AppThemeVariant.medium:
        return 'Medium (fioletowy)';
      case AppThemeVariant.royalPurple:
        return 'Royal purple';
      case AppThemeVariant.elegantLight:
        return settings.themeMode == ThemeMode.dark ? 'Ciemny (jasny)' : 'Jasny (elegancki)';
      default:
        return settings.themeMode == ThemeMode.dark ? 'Ciemny' : 'Jasny';
    }
  }

  List<_SettingsItem> _buildAppearanceItems(SettingsProvider settings) {
    return [
      _SettingsItem(
        icon: Icons.palette_outlined,
        title: 'Wygląd',
        subtitle: 'Motyw: ${_themeLabel(settings)}',
        section: 'Wygląd',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppearanceSettingsPage())),
      ),
    ];
  }

  // ─── SEKCJA POWIADOMIENIA ───

  List<_SettingsItem> _buildNotificationItems(SettingsProvider settings) {
    return [
      _SettingsItem(
        icon: Icons.notifications_outlined,
        title: 'Powiadomienia',
        subtitle: settings.notificationsEnabled
            ? 'Sowa: wł. • pasek sportowy: ${settings.showSportsBar ? 'wł.' : 'wył.'}'
            : 'Sowa: wył. • pasek sportowy: ${settings.showSportsBar ? 'wł.' : 'wył.'}',
        section: 'Powiadomienia',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsPage())),
      ),
    ];
  }

  // ─── SEKCJA TREŚCI ───

  List<_SettingsItem> _buildContentItems() {
    return [
      _SettingsItem(
        icon: Icons.rss_feed,
        title: 'Źródła RSS',
        subtitle: 'Lokalne źródła i portale',
        section: 'Treści',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SourceSettingsPage())),
      ),
      _SettingsItem(
        icon: Icons.category_outlined,
        title: 'Kategorie',
        subtitle: 'Zakładki główne, kolejność w Tematach',
        section: 'Treści',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategorySettingsPage())),
      ),
      _SettingsItem(
        icon: Icons.psychology_outlined,
        title: 'Zainteresowania',
        subtitle: 'Słowa kluczowe, tematy newsów',
        section: 'Treści',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InterestsSettingsPage())),
      ),
      _SettingsItem(
        icon: Icons.label_outlined,
        title: 'Tagi',
        subtitle: 'Twórz i zarządzaj tagami artykułów',
        section: 'Treści',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TagSettingsPage())),
      ),
    ];
  }

  // ─── SEKCJA SPORT ───

  List<_SettingsItem> _buildSportItems(SettingsProvider settings) {
    final count = settings.selectedLeagueIds.length;
    return [
      _SettingsItem(
        icon: Icons.sports_soccer,
        title: 'Sport',
        subtitle: count == 0
            ? 'Ligi, drużyny, pasek wyników'
            : 'Wybrano $count ${count == 1 ? 'ligę' : count < 5 ? 'ligi' : 'lig'} • drużyny, faworyci',
        section: 'Sport',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SportSettingsPage())),
      ),
    ];
  }

  // ─── SEKCJA DANE I NARZĘDZIA ───

  List<_SettingsItem> _buildToolsItems() {
    return [
      _SettingsItem(
        icon: Icons.download,
        title: 'Eksportuj ustawienia',
        subtitle: 'Zapisz kopię zapasową',
        section: 'Dane i narzędzia',
        onTap: _exportSettings,
      ),
      _SettingsItem(
        icon: Icons.upload,
        title: 'Importuj ustawienia',
        subtitle: 'Przywróć z kopii zapasowej',
        section: 'Dane i narzędzia',
        onTap: _importSettings,
      ),
      _SettingsItem(
        icon: Icons.cleaning_services_outlined,
        title: 'Wyczyść pamięć podręczną',
        subtitle: 'Usuń przechowane newsy i odśwież zawartość',
        section: 'Dane i narzędzia',
        onTap: _clearCache,
      ),
    ];
  }

  // ─── SEKCJA O APLIKACJI ───

  List<_SettingsItem> _buildAboutItems() {
    return [
      _SettingsItem(
        icon: Icons.info_outline,
        title: 'O aplikacji',
        subtitle: 'Wersja, polityka prywatności, kontakt, licencje',
        section: 'O aplikacji',
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage())),
      ),
    ];
  }

  // ─── AKCJE ───

  Future<void> _exportSettings() async {
    try {
      final settingsBox = Hive.box('settings');
      final data = <String, dynamic>{};
      for (final key in settingsBox.keys) {
        final value = settingsBox.get(key);
        if (value is List) {
          data[key.toString()] = value;
        } else if (value is num || value is bool || value is String) {
          data[key.toString()] = value;
        }
      }
      final json = const JsonEncoder.withIndent('  ').convert({
        'version': '1.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': data,
      });

      await SharePlus.instance.share(
        ShareParams(text: json, subject: 'Prasówka — kopia zapasowa ustawień'),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ustawienia wyeksportowane')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd eksportu: $e')),
        );
      }
    }
  }

  Future<void> _importSettings() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text == null || data!.text!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Schowek jest pusty')),
          );
        }
        return;
      }

      final parsed = jsonDecode(data.text!) as Map<String, dynamic>;
      if (!parsed.containsKey('settings')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nieprawidłowy format kopii zapasowej')),
          );
        }
        return;
      }

      final settings = parsed['settings'] as Map<String, dynamic>;
      final box = Hive.box('settings');
      for (final entry in settings.entries) {
        await box.put(entry.key, entry.value);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ustawienia przywrócone — uruchom ponownie aplikację')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd importu: $e')),
        );
      }
    }
  }

  Future<void> _clearCache() async {
    final settingsProvider = context.read<SettingsProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wyczyścić pamięć podręczną?'),
        content: const Text('Zostaną usunięte przechowane artykuły, a zawartość zostanie odświeżona. Twoje ustawienia nie zostaną zmienione.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Wyczyść')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await settingsProvider.clearNewsCache();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pamięć podręczna wyczyszczona')),
      );
    }
  }

  // ─── BUILD ───

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final sync = context.watch<SyncService>();
    final settings = context.watch<SettingsProvider>();

    final allItems = [
      ..._buildAccountItems(auth, sync),
      ..._buildAppearanceItems(settings),
      ..._buildNotificationItems(settings),
      ..._buildContentItems(),
      ..._buildSportItems(settings),
      ..._buildToolsItems(),
      ..._buildAboutItems(),
    ];

    final filteredItems = _searchQuery.isEmpty ? allItems : allItems.where((item) =>
      item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      item.subtitle.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    final seen = <String>{};
    final sections = filteredItems.where((item) => seen.add(item.section)).map((item) => item.section).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('USTAWIENIA'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Szukaj ustawień...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'Brak wyników',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.only(bottom: 80),
                    children: [
                      for (final section in sections) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                          child: Text(
                            section.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentFor(context),
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        ...filteredItems
                            .where((item) => item.section == section)
                            .map(_buildTile),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.day}.${dt.month}.${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildTile(_SettingsItem item) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.accentFor(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(item.icon, color: AppTheme.accentFor(context)),
      ),
      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(item.subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: item.onTap,
    );
  }
}
