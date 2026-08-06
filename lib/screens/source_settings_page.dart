import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/news_source.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/settings_provider.dart';

class SourceSettingsPage extends StatelessWidget {
  const SourceSettingsPage({super.key});

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
    final categories = settings.allCategories.where((c) => c.id != 'all').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('ZARZĄDZANIE ŹRÓDŁAMI')),
      body: ListView(
        children: [
          // ─── SEKCJA: Miasto ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'TWOJE MIASTO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentFor(context),
                letterSpacing: 0.8,
              ),
            ),
          ),
          ..._cities.map((c) {
            final isSelected = city == c['name'];
            return ListTile(
              dense: true,
              leading: Icon(
                Icons.location_on,
                color: isSelected ? AppTheme.accentFor(context) : Colors.grey,
                size: 20,
              ),
              title: Text(
                c['name'] as String,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.accentFor(context) : null,
                  fontSize: 14,
                ),
              ),
              trailing: isSelected ? Icon(Icons.check, color: AppTheme.accentFor(context), size: 20) : null,
              onTap: () => settings.setPreferredCity(c['name'] as String, c['lat'] as double, c['lon'] as double),
            );
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Po zmianie miasta źródła lokalne są automatycznie włączane.',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
          const Divider(height: 24),

          // ─── SEKCJA: Źródła wg kategorii ───
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              'ŹRÓDŁA wg KATEGORII',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentFor(context),
                letterSpacing: 0.8,
              ),
            ),
          ),
          for (final cat in categories) ...[
            _buildCategoryTile(context, cat, settings, city),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(BuildContext context, dynamic cat, SettingsProvider settings, String city) {
    var sources = settings.allSources.where((s) => s.categoryId == cat.id).toList();

    // Dla kategorii "warsaw" podmień źródła na te z wybranego miasta
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
    final activeCount = sources.where((s) => settings.isSourceActive(s.id)).length;

    return ExpansionTile(
      leading: Icon(cat.icon, color: AppTheme.accentFor(context), size: 20),
      title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(
        '$activeCount / ${sources.length} włączonych',
        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
      ),
      children: sources.map((src) => CheckboxListTile(
        dense: true,
        title: Text(src.name, style: const TextStyle(fontSize: 13)),
        subtitle: Text(src.rssUrl, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
        value: settings.isSourceActive(src.id),
        activeColor: AppTheme.accentFor(context),
        onChanged: (_) => settings.toggleSource(src.id),
      )).toList(),
    );
  }
}
