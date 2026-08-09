import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/settings_provider.dart';

class InterestsSettingsPage extends StatefulWidget {
  const InterestsSettingsPage({super.key});

  @override
  State<InterestsSettingsPage> createState() => _InterestsSettingsPageState();
}

class _InterestsSettingsPageState extends State<InterestsSettingsPage> {
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
      appBar: AppBar(title: const Text('ZAINTERESOWANIA')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'TEMATY, DRUŻYNY I LIGI',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.accentFor(context),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Wpisz nazwę klubu lub ligi (np. "Legia", "Ekstraklasa", "NBA"), aby otrzymywać spersonalizowane newsy.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          if (settings.keywords.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: settings.keywords.map((team) => Chip(
                label: Text(team),
                onDeleted: () => settings.removeKeyword(team),
                deleteIconColor: Colors.red,
                backgroundColor: AppTheme.accentFor(context).withValues(alpha: 0.1),
                side: BorderSide(color: AppTheme.accentFor(context)),
              )).toList(),
            ),
          Text(
            '${settings.keywords.length}/${SettingsProvider.maxKeywords}',
            style: TextStyle(
              fontSize: 11,
              color: settings.keywords.length >= SettingsProvider.maxKeywords
                  ? Colors.red
                  : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            enabled: settings.keywords.length < SettingsProvider.maxKeywords,
            decoration: InputDecoration(
              hintText: settings.keywords.length >= SettingsProvider.maxKeywords
                  ? 'Osiągnięto limit ${SettingsProvider.maxKeywords} haseł'
                  : 'Dodaj nowe hasło...',
              suffixIcon: IconButton(
                icon: Icon(Icons.add_circle, color: AppTheme.accentFor(context)),
                onPressed: settings.keywords.length < SettingsProvider.maxKeywords
                    ? () => _submit(settings)
                    : null,
              ),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.1),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onSubmitted: (_) => _submit(settings),
          ),
          const SizedBox(height: 32),
          Text(
            'PODPOWIEDZI',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.accentFor(context),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Możesz tu dodać dowolne hasła, np. "Iga Świątek", "Tesla", "Górnik Zabrze" czy "Giełda". Sowa automatycznie przefiltruje dla Ciebie internet.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
