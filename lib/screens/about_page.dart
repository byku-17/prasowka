import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:prasowka/theme/app_theme.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = '${info.version} (${info.buildNumber})');
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accentFor(context);

    return Scaffold(
      appBar: AppBar(title: const Text('O APLIKACJI')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.newspaper, size: 44, color: accent),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'Prasówka',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              _version ?? 'Wersja...',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Twoja osobista prasówka — ważne newsy z sieci, wybrane dla Ciebie.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          const Divider(height: 40),
          ListTile(
            leading: Icon(Icons.privacy_tip_outlined, color: accent),
            title: const Text('Polityka prywatności'),
            subtitle: const Text('Jak traktujemy Twoje dane'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showInfo(context,
              title: 'Polityka prywatności',
              body: 'Prasówka przetwarza Twoje dane lokalnie na urządzeniu. '
                    'Zainteresowania, ulubione drużyny i ustawienia są przechowywane na Twoim telefonie.\n\n'
                    'Dane logowania są przechowywane lokalnie (Hive) i nie są wysyłane nigdzie indziej niż do naszej chmury synchronizacji, jeśli z niej korzystasz.\n\n'
                    'Nie sprzedajemy ani nie udostępniamy Twoich danych osobom trzecim.',
            ),
          ),
          ListTile(
            leading: Icon(Icons.mail_outline, color: accent),
            title: const Text('Kontakt / zgłoś problem'),
            subtitle: const Text('Napisz do nas, jeśli coś nie działa'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showInfo(context,
              title: 'Kontakt',
              body: 'Znalazłeś błąd lub masz pomysł na ulepszenie Prasówki?\n\n'
                    'Napisz do nas:\nprasowka@example.com\n\n'
                    'Opisz, co się stało, na jakim urządzeniu i w której wersji aplikacji.',
            ),
          ),
          ListTile(
            leading: Icon(Icons.code, color: accent),
            title: const Text('Licencje open-source'),
            subtitle: const Text('Biblioteki, z których korzystamy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showInfo(context,
              title: 'Licencje open-source',
              body: 'Prasówka używa otwartych bibliotek Fluttera, m.in.:\n\n'
                    '• Provider (MIT)\n'
                    '• Hive (Apache-2.0)\n'
                    '• package_info_plus (BSD-3-Clause)\n'
                    '• share_plus (BSD-3-Clause)\n'
                    '• http (BSD-3-Clause)\n\n'
                    'Pełna lista licencji dostępna jest w aplikacji Flutter (About) oraz w repozytorium projektu.',
            ),
          ),
        ],
      ),
    );
  }

  void _showInfo(BuildContext context, {required String title, required String body}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(body, style: const TextStyle(fontSize: 13, height: 1.5)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: TextStyle(color: AppTheme.accentFor(context))),
          ),
        ],
      ),
    );
  }
}
