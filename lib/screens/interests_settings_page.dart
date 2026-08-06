import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/sport_league.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/providers/sports_provider.dart';

class InterestsSettingsPage extends StatefulWidget {
  const InterestsSettingsPage({super.key});

  @override
  State<InterestsSettingsPage> createState() => _InterestsSettingsPageState();
}

class _InterestsSettingsPageState extends State<InterestsSettingsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MOJE ZAINTERESOWANIA'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentFor(context),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
          tabs: const [
            Tab(text: 'TEMATY'),
            Tab(text: 'WYNIKI LIVE'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTopicsTab(),
          _buildLiveScoresTab(),
        ],
      ),
    );
  }

  // ─── ZAKŁADKA 1: TEMATY ( słowa kluczowe do newsów ) ───

  Widget _buildTopicsTab() {
    return _TopicsTab();
  }

  // ─── ZAKŁADKA 2: WYNIKI LIVE ( ligi + drużyny ) ───

  Widget _buildLiveScoresTab() {
    return _LiveScoresTab();
  }
}

// ═══════════════════════════════════════════
//  TEMATY — słowa kluczowe do filtrowania newsów
// ═══════════════════════════════════════════

class _TopicsTab extends StatefulWidget {
  @override
  State<_TopicsTab> createState() => _TopicsTabState();
}

class _TopicsTabState extends State<_TopicsTab> {
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

    return ListView(
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
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Dodaj nowe hasło...',
            suffixIcon: IconButton(
              icon: Icon(Icons.add_circle, color: AppTheme.accentFor(context)),
              onPressed: () => _submit(settings),
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
    );
  }
}

// ═══════════════════════════════════════════
//  WYNIKI LIVE — ligi + ulubione drużyny
// ═══════════════════════════════════════════

class _LiveScoresTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // Wybrane ligi
        _buildLeagueSection(context, settings),
        const Divider(height: 32),
        // Ulubione drużyny
        _buildFavoriteTeamsSection(context, settings),
        const SizedBox(height: 8),
        // Pasek informacyjny
        _buildInfoBar(context, settings),
        // Debug
        _buildDebugToggle(context),
      ],
    );
  }

  // ─── WYBRANE LIGI ───

  Widget _buildLeagueSection(BuildContext context, SettingsProvider settings) {
    final selected = settings.selectedLeagueIds
        .map((id) => SportLeague.findById(id))
        .whereType<SportLeague>()
        .toList();

    final Map<SportDiscipline, List<SportLeague>> grouped = {};
    for (final league in selected) {
      grouped.putIfAbsent(league.discipline, () => []).add(league);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Center(
            child: ElevatedButton.icon(
              onPressed: () => _showLeaguePicker(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentFor(context).withValues(alpha: 0.15),
                foregroundColor: AppTheme.accentFor(context),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('WYBIERZ LIGI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ),
        if (selected.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              children: [
                Icon(Icons.sports_soccer, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                const Text(
                  'Nie wybrano żadnych lig.\nKliknij "Wybierz Ligi" powyżej.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          )
        else
          for (final entry in grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Text(
                '${entry.key.emoji}  ${entry.key.displayName.toUpperCase()}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentFor(context),
                  letterSpacing: 1.0,
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      color: Theme.of(context).cardColor,
      child: ListTile(
        dense: true,
        leading: _buildCountryFlag(league.countryCode),
        title: Text(league.name, style: const TextStyle(fontSize: 14)),
        subtitle: Text(league.country, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
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
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(code == 'EU' ? 'EU' : '🌍', style: const TextStyle(fontSize: 12)),
        ),
      );
    }
    return Container(
      width: 32,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text(code, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ─── ULUBIONE DRUŻYNY ───

  Widget _buildFavoriteTeamsSection(BuildContext context, SettingsProvider settings) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.star, size: 16, color: AppTheme.accentFor(context)),
                  const SizedBox(width: 8),
                  Text(
                    'ULUBIONE DRUŻYNY / ZAWODNICY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentFor(context),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _showAddFavoriteDialog(context, settings),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Dodaj', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accentFor(context),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          if (settings.favoriteTeams.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Dodaj drużyny (np. "Wisła"), zawodników (np. "Świątek") lub kierowców F1.',
                style: TextStyle(fontSize: 12, color: Colors.grey.withValues(alpha: 0.7)),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: settings.favoriteTeams.map((team) => Chip(
                  label: Text(team, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => settings.removeFavoriteTeam(team),
                  backgroundColor: AppTheme.accentFor(context).withValues(alpha: 0.12),
                  deleteIconColor: AppTheme.accentFor(context).withValues(alpha: 0.7),
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
              if (name.isNotEmpty) settings.addFavoriteTeam(name);
              Navigator.pop(ctx);
            },
            child: Text('Dodaj', style: TextStyle(color: AppTheme.accentFor(context))),
          ),
        ],
      ),
    );
  }

  // ─── PASEK INFORMACYJNY ───

  Widget _buildInfoBar(BuildContext context, SettingsProvider settings) {
    final count = settings.selectedLeagueIds.length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accentFor(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count == 0
            ? 'Wybierz ligi, aby zobaczyć wyniki na pasku sportowym'
            : 'Wybrano $count ${count == 1 ? "ligę" : count < 5 ? "ligi" : "lig"}',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: count == 0 ? Colors.grey : AppTheme.accentFor(context),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ─── DEBUG ───

  Widget _buildDebugToggle(BuildContext context) {
    return Consumer<SportsProvider>(
      builder: (context, provider, _) {
        if (provider.debugLogs.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              leading: Icon(Icons.bug_report, size: 18, color: Colors.orange.shade700),
              title: Text(
                'Diagnostyka (${provider.debugLogs.length})',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...provider.debugLogs.take(30).map((log) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(log, style: const TextStyle(fontSize: 10, color: Colors.orange)),
                      )),
                      if (provider.events.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'W pamięci: ${provider.events.length} meczów',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── LEAGUE PICKER ───

  void _showLeaguePicker(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const _LeaguePickerScreen()));
  }
}

// ═══════════════════════════════════════════
//  LEAGUE PICKER — pełna lista lig do wyboru
// ═══════════════════════════════════════════

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
            title: Text(discipline.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                subtitle: Text(league.country, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
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
