import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/widgets/section_header.dart';

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
          const SectionHeader('TEMATY, DRUŻYNY I LIGI'),
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
          const SectionHeader('PODPOWIEDZI'),
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
