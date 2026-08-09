import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/settings_provider.dart';

class ExcludedWordsPage extends StatefulWidget {
  const ExcludedWordsPage({super.key});

  @override
  State<ExcludedWordsPage> createState() => _ExcludedWordsPageState();
}

class _ExcludedWordsPageState extends State<ExcludedWordsPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(SettingsProvider settings) {
    if (_controller.text.isNotEmpty) {
      settings.addExcludedWord(_controller.text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('SŁOWA WYKLUCZAJĄCE')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'FILTROWANIE ARTYKUŁÓW',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.accentFor(context),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Wpisz słowa, których nie chcesz widzieć w artykułach (np. "krypto", "pogoda", "plotki"). Artykuły zawierające je w tytule lub opisie będą ukrywane.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          if (settings.excludedWords.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: settings.excludedWords.map((word) => Chip(
                label: Text(word),
                onDeleted: () => settings.removeExcludedWord(word),
                deleteIconColor: Colors.red,
                backgroundColor: Colors.red.withValues(alpha: 0.08),
                side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
              )).toList(),
            ),
          Text(
            '${settings.excludedWords.length}/${SettingsProvider.maxKeywords}',
            style: TextStyle(
              fontSize: 11,
              color: settings.excludedWords.length >= SettingsProvider.maxKeywords
                  ? Colors.red
                  : Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            enabled: settings.excludedWords.length < SettingsProvider.maxKeywords,
            decoration: InputDecoration(
              hintText: settings.excludedWords.length >= SettingsProvider.maxKeywords
                  ? 'Osiągnięto limit ${SettingsProvider.maxKeywords} słów'
                  : 'Dodaj słowo do wykluczenia...',
              suffixIcon: IconButton(
                icon: Icon(Icons.add_circle, color: AppTheme.accentFor(context)),
                onPressed: settings.excludedWords.length < SettingsProvider.maxKeywords
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
            'Słowa działają nierozróżnialnie na wielkość liter i usuwają artykuły z list podczas odświeżania. Zapisane i polubione artykuły zawsze zostają.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
