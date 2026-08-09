import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/widgets/section_header.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('POWIADOMIENIA')),
      body: ListView(
        children: [
          const SectionHeader('WARTOWNIK SOWY'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Powiadamiaj o ważnych tematach'),
            subtitle: const Text('Sowa będzie szukać newsów w tle i da znać o tych, które pasują do Twoich polubień.'),
            value: settings.notificationsEnabled,
            onChanged: (val) => settings.toggleNotifications(val),
            activeThumbColor: AppTheme.accentFor(context),
          ),
          if (settings.notificationsEnabled) ...[
            const Divider(),
            const SectionHeader('GODZINY DZIAŁANIA'),
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Godziny działania'),
              subtitle: Text('${_formatHour(settings.notificationStartHour)} – ${_formatHour(settings.notificationEndHour)}'),
              onTap: () => _showHoursPicker(context, settings),
            ),
            ListTile(
              leading: const Icon(Icons.hourglass_empty_outlined),
              title: const Text('Częstotliwość sprawdzania'),
              subtitle: Text(_checkFrequencyLabel(settings.notificationCheckFrequencyHours)),
              onTap: () => _showCheckFrequencyPicker(context, settings),
            ),
          ],
          const Divider(),
          const SectionHeader('WIDOK SPORTOWY'),
          SwitchListTile(
            secondary: const Icon(Icons.sports_score_outlined),
            title: const Text('Pokaż wyniki meczów'),
            subtitle: const Text('Wyświetla pasek z wynikami na górze sekcji Sport.'),
            value: settings.showSportsBar,
            onChanged: (val) => settings.toggleSportsBar(val),
            activeThumbColor: AppTheme.accentFor(context),
          ),
        ],
      ),
    );
  }

  String _formatHour(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  String _checkFrequencyLabel(int hours) {
    switch (hours) {
      case 3:
        return 'Co 3 godziny';
      case 24:
        return 'Raz dziennie';
      default:
        return 'Co godzinę';
    }
  }

  void _showCheckFrequencyPicker(BuildContext context, SettingsProvider settings) {
    final options = <(int, String, String)>[
      (1, 'Co godzinę', 'Sowa sprawdza nowości co godzinę'),
      (3, 'Co 3 godziny', 'Sowa sprawdza nowości co 3 godziny'),
      (24, 'Raz dziennie', 'Sowa sprawdza nowości raz dziennie'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Częstotliwość sprawdzania',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            for (final (hours, label, desc) in options)
              ListTile(
                leading: Icon(
                  hours == settings.notificationCheckFrequencyHours
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: AppTheme.accentFor(context),
                ),
                title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                onTap: () {
                  settings.setNotificationCheckFrequencyHours(hours);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showHoursPicker(BuildContext context, SettingsProvider settings) {
    var start = settings.notificationStartHour;
    var end = settings.notificationEndHour;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          Widget hourDropdown(String label, int value, ValueChanged<int?> onChanged) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                DropdownButton<int>(
                  value: value,
                  isExpanded: true,
                  items: [
                    for (var h = 0; h < 24; h++)
                      DropdownMenuItem(value: h, child: Text(_formatHour(h))),
                  ],
                  onChanged: onChanged,
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Godziny działania'),
            content: Row(
              children: [
                Expanded(child: hourDropdown('Od', start, (v) => v != null ? setState(() => start = v) : null)),
                const SizedBox(width: 16),
                Expanded(child: hourDropdown('Do', end, (v) => v != null ? setState(() => end = v) : null)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anuluj')),
              TextButton(
                onPressed: () {
                  settings.setNotificationHours(start, end);
                  Navigator.pop(ctx);
                },
                child: Text('Zapisz', style: TextStyle(color: AppTheme.accentFor(context))),
              ),
            ],
          );
        },
      ),
    );
  }
}
