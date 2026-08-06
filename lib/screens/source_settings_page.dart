import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/news_source.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/settings_provider.dart';

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
          
          if (cat.id == 'warsaw') {
            final sourceIds = NewsSource.cityRssSourceIds[city];
            if (sourceIds != null) {
              sources = settings.allSources.where((s) => sourceIds.contains(s.id)).toList();
            } else {
              sources = settings.allSources.where((s) => s.categoryId == 'warsaw').toList();
            }
          }
          
          if (sources.isEmpty) return const SizedBox.shrink();

          final displayName = cat.id == 'warsaw' ? city : cat.name;

          return ExpansionTile(
            leading: Icon(cat.icon, color: AppTheme.accentFor(context), size: 20),
            title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            children: sources.map((src) => CheckboxListTile(
              title: Text(src.name, style: const TextStyle(fontSize: 13)),
              subtitle: Text(src.rssUrl, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
              value: settings.isSourceActive(src.id),
              activeColor: AppTheme.accentFor(context),
              onChanged: (_) => settings.toggleSource(src.id),
            )).toList(),
          );
        },
      ),
    );
  }
}
