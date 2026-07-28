import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/news_source.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/widgets/section_header.dart';

class CitySourcesPage extends StatelessWidget {
  const CitySourcesPage({super.key});

  static const _cities = [
    {'name': 'Warszawa', 'lat': 52.2297, 'lon': 21.0122},
    {'name': 'Kraków', 'lat': 50.0647, 'lon': 19.9450},
    {'name': 'Wrocław', 'lat': 51.1079, 'lon': 17.0385},
    {'name': 'Gdańsk', 'lat': 54.3520, 'lon': 18.6466},
    {'name': 'Poznań', 'lat': 52.4064, 'lon': 16.9252},
    {'name': 'Łódź', 'lat': 51.7592, 'lon': 19.4560},
    {'name': 'Katowice', 'lat': 50.2649, 'lon': 19.0238},
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final city = settings.preferredCity;
    final citySourceIds = NewsSource.cityRssSourceIds[city] ?? [];
    final citySources = settings.allSources.where((s) => citySourceIds.contains(s.id)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('MIASTO I ŹRÓDŁA')),
      body: ListView(
        children: [
          const SectionHeader('TWOJE MIASTO'),
          ..._cities.map((c) {
            final isSelected = city == c['name'];
            return ListTile(
              leading: Icon(
                Icons.location_on,
                color: isSelected ? AppTheme.accentGold : Colors.grey,
              ),
              title: Text(
                c['name'] as String,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.accentGold : null,
                ),
              ),
              trailing: isSelected ? const Icon(Icons.check, color: AppTheme.accentGold) : null,
              onTap: () {
                settings.setPreferredCity(c['name'] as String, c['lat'] as double, c['lon'] as double);
              },
            );
          }),
          const Divider(height: 32),
          const SectionHeader('ŹRÓDŁA LOCALNE'),
          if (citySources.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Brak źródeł dla tego miasta', style: TextStyle(color: Colors.grey)),
            )
          else
            ...citySources.map((src) => CheckboxListTile(
              secondary: Icon(Icons.rss_feed, color: AppTheme.accentGold, size: 20),
              title: Text(src.name, style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                src.rssUrl,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              value: settings.isSourceActive(src.id),
              activeColor: AppTheme.accentGold,
              onChanged: (_) => settings.toggleSource(src.id),
            )),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Po zmianie miasta źródła lokalne są automatycznie włączane.',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}
