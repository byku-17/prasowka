import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'PERSONALIZACJA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.accentGold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Tryb ciemny'),
            subtitle: const Text('Podążaj za ustawieniami systemu'),
            trailing: Switch(
              value: true, // TODO: Implementacja ThemeProvider
              onChanged: (val) {},
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'INFORMACJE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.accentGold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('O aplikacji'),
            subtitle: Text('Prasówka v1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.code),
            title: Text('Autor'),
            subtitle: Text('Zbudowano z pomocą AI'),
          ),
        ],
      ),
    );
  }
}
