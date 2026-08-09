import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/services/sync_service.dart';

class SyncScopePage extends StatelessWidget {
  const SyncScopePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    final scopes = <(String, IconData, String, String)>[
      (SyncService.scopeSettings, Icons.settings_outlined, 'Ustawienia', 'Motyw, powiadomienia, sport, kolejność'),
      (SyncService.scopeTags, Icons.label_outline, 'Tagi', 'Twoje tagi artykułów'),
      (SyncService.scopeArticles, Icons.bookmark_outline, 'Zapisane artykuły', 'Stan zapisanych, polubionych i przeczytanych artykułów'),
      (SyncService.scopeInterests, Icons.psychology_outlined, 'Zainteresowania', 'Słowa kluczowe i oceny dopasowania'),
      (SyncService.scopeCategories, Icons.category_outlined, 'Kategorie', 'Własne kategorie i zakładki główne'),
      (SyncService.scopeSources, Icons.rss_feed, 'Źródła RSS', 'Lista i aktywacja źródeł'),
      (SyncService.scopeReading, Icons.history, 'Historia czytania', 'Historia otwieranych artykułów'),
      (SyncService.scopePinned, Icons.push_pin_outlined, 'Przypięte mecze', 'Przypięte mecze sportowe'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('CO SYNCHRONIZOWAĆ')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Wybierz, które dane mają być wysyłane do chmury i pobierane z innych urządzeń. Wyłączenie zakresu nie usuwa danych lokalnie.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          for (final (scope, icon, title, desc) in scopes)
            CheckboxListTile(
              secondary: Icon(icon, color: AppTheme.accentFor(context)),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              value: settings.isSyncScopeEnabled(scope),
              onChanged: (val) => settings.toggleSyncScope(scope, val ?? false),
              activeColor: AppTheme.accentFor(context),
            ),
        ],
      ),
    );
  }
}
