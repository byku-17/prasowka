import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/sport_league.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/providers/sports_provider.dart';
import 'package:prasowka/theme/app_theme.dart';

class SportSettingsScreen extends StatelessWidget {
  const SportSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MOJE SPORTY'),
        actions: [
          if (settings.selectedLeagueIds.isNotEmpty)
            TextButton(
              onPressed: () => settings.setSelectedLeagues([]),
              child: const Text('Wyczyść', style: TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
      body: settings.selectedLeagueIds.isEmpty
          ? _buildEmptyState(context)
          : _buildSelectedSummary(context, settings),
      bottomNavigationBar: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFavoriteTeamsSection(context, settings),
            _buildDebugSection(context),
            _buildInfoBar(settings),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugSection(BuildContext context) {
    return Consumer<SportsProvider>(
      builder: (context, provider, _) {
        if (provider.debugLogs.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DEBUG', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(height: 4),
              ...provider.debugLogs.take(20).map((log) => Text(
                log,
                style: const TextStyle(fontSize: 10, color: Colors.orange),
              )),
              if (provider.events.isNotEmpty)
                Text(
                  'Wydruk: ${provider.events.length} meczów w pamięci',
                  style: const TextStyle(fontSize: 10, color: Colors.green),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFavoriteTeamsSection(BuildContext context, SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentGold.withValues(alpha: 0.05),
        border: Border(top: BorderSide(color: AppTheme.accentGold.withValues(alpha: 0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: AppTheme.accentGold),
                  const SizedBox(width: 8),
                  Text(
                    'ULUBIONE DRUŻYNY / ZAWODNICY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentGold.withValues(alpha: 0.9),
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _showAddFavoriteDialog(context, settings),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Dodaj', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accentGold,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          if (settings.favoriteTeams.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Dodaj drużyny (np. "Wisła"), zawodników (np. "Świątek") lub kierowców F1 (np. "Verstappen") — pokażemy tylko ich mecze.',
                style: TextStyle(fontSize: 11, color: Colors.grey.withValues(alpha: 0.7)),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: settings.favoriteTeams.map((team) => Chip(
                  label: Text(team, style: const TextStyle(fontSize: 11)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => settings.removeFavoriteTeam(team),
                  backgroundColor: AppTheme.accentGold.withValues(alpha: 0.15),
                  deleteIconColor: AppTheme.accentGold.withValues(alpha: 0.7),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddFavoriteDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dodaj ulubioną drużynę / zawodnika'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'np. Wisła, Świątek, Verstappen...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                settings.addFavoriteTeam(name);
              }
              Navigator.pop(ctx);
            },
            child: Text('Dodaj', style: TextStyle(color: AppTheme.accentFor(context))),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sports_soccer, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Nie wybrano żadnych lig',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kliknij "Wybierz Ligi" poniżej,\naby dodać wyniki do paska sportowego.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showLeaguePicker(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentFor(context),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('WYBIERZ LIGI', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedSummary(BuildContext context, SettingsProvider settings) {
    final selected = settings.selectedLeagueIds
        .map((id) => SportLeague.findById(id))
        .whereType<SportLeague>()
        .toList();

    // Group by discipline
    final Map<SportDiscipline, List<SportLeague>> grouped = {};
    for (final league in selected) {
      grouped.putIfAbsent(league.discipline, () => []).add(league);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Add more button at top
        Center(
          child: ElevatedButton.icon(
            onPressed: () => _showLeaguePicker(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGold.withValues(alpha: 0.2),
              foregroundColor: AppTheme.accentFor(context),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('DODAJ WIĘCEJ LIG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        const SizedBox(height: 16),
        // Grouped leagues
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8, top: 16),
            child: Text(
              '${entry.key.emoji} ${entry.key.displayName.toUpperCase()}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentGold.withValues(alpha: 0.8),
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...entry.value.map((league) => _buildLeagueTile(context, league, settings)),
        ],
      ],
    );
  }

  Widget _buildLeagueTile(BuildContext context, SportLeague league, SettingsProvider settings) {
    final isSelected = settings.selectedLeagueIds.contains(league.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: Theme.of(context).cardColor,
      child: ListTile(
        leading: _buildCountryFlag(league.countryCode),
        title: Text(
          league.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          league.country,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        trailing: Switch(
          value: isSelected,
          onChanged: (_) => settings.toggleLeague(league.id),
          activeThumbColor: AppTheme.accentFor(context),
        ),
        onTap: () => settings.toggleLeague(league.id),
      ),
    );
  }

  Widget _buildCountryFlag(String? code) {
    if (code == null || code == 'WORLD' || code == 'EU') {
      return Container(
        width: 32,
        height: 22,
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            code == 'EU' ? 'EU' : '🌍',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      );
    }
    return Container(
      width: 32,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(
          code,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildInfoBar(SettingsProvider settings) {
    final count = settings.selectedLeagueIds.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentGold.withValues(alpha: 0.1),
        border: Border(top: BorderSide(color: AppTheme.accentGold.withValues(alpha: 0.3))),
      ),
      child: SafeArea(
        child: Text(
          count == 0
              ? 'Wybierz ligi, aby zobaczyć wyniki na pasku sportowym'
              : 'Wybrano $count ${count == 1 ? "ligę" : count < 5 ? "ligi" : "lig"}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: count == 0 ? Colors.grey : AppTheme.accentGold,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showLeaguePicker(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _LeaguePickerScreen()),
    );
  }
}

// ─── PEŁNA LISTA LIG DO WYBORU ───

class _LeaguePickerScreen extends StatefulWidget {
  const _LeaguePickerScreen();

  @override
  State<_LeaguePickerScreen> createState() => _LeaguePickerScreenState();
}

class _LeaguePickerScreenState extends State<_LeaguePickerScreen> {
  late List<String> _tempSelected;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.read<SettingsProvider>();
    _tempSelected = List<String>.from(settings.selectedLeagueIds);
  }

  bool _isSelected(String id) => _tempSelected.contains(id);

  void _toggle(String id) {
    setState(() {
      if (_tempSelected.contains(id)) {
        _tempSelected.remove(id);
      } else {
        _tempSelected.add(id);
      }
    });
  }

  void _selectAll(List<SportLeague> leagues) {
    setState(() {
      for (final l in leagues) {
        if (!_tempSelected.contains(l.id)) _tempSelected.add(l.id);
      }
    });
  }

  void _deselectAll(List<SportLeague> leagues) {
    setState(() {
      final ids = leagues.map((l) => l.id).toSet();
      _tempSelected.removeWhere((id) => ids.contains(id));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WYBIERZ LIGI'),
        actions: [
          TextButton(
            onPressed: () {
              context.read<SettingsProvider>().setSelectedLeagues(_tempSelected);
              Navigator.pop(context);
            },
            child: Text('Zapisz', style: TextStyle(color: AppTheme.accentFor(context), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: SportDiscipline.values.length,
        itemBuilder: (context, index) {
          final discipline = SportDiscipline.values[index];
          final leagues = SportLeague.forDiscipline(discipline);
          final allSelected = leagues.every((l) => _tempSelected.contains(l.id));
          final someSelected = leagues.any((l) => _tempSelected.contains(l.id));

          return ExpansionTile(
            initiallyExpanded: someSelected,
            leading: Text(discipline.emoji, style: const TextStyle(fontSize: 24)),
            title: Text(
              discipline.displayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '$someSelected z ${leagues.length} lig',
              style: TextStyle(
                fontSize: 11,
                color: someSelected ? AppTheme.accentFor(context) : Colors.grey,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(allSelected ? Icons.deselect : Icons.select_all, size: 20),
                  tooltip: allSelected ? 'Odznacz wszystkie' : 'Zaznacz wszystkie',
                  onPressed: () => allSelected ? _deselectAll(leagues) : _selectAll(leagues),
                ),
                Icon(someSelected ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
              ],
            ),
            children: leagues.map((league) {
              final selected = _isSelected(league.id);
              return CheckboxListTile(
                value: selected,
                onChanged: (_) => _toggle(league.id),
                activeColor: AppTheme.accentFor(context),
                title: Text(league.name, style: const TextStyle(fontSize: 14)),
                subtitle: Text(
                  league.country,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                secondary: selected
                    ? Icon(Icons.check_circle, color: AppTheme.accentFor(context), size: 20)
                    : Icon(Icons.circle_outlined, color: Colors.grey.withValues(alpha: 0.5), size: 20),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
