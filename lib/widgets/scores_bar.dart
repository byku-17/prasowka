import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/sport_event.dart';
import 'package:prasowka/models/sport_league.dart';
import 'package:prasowka/providers/sports_provider.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/screens/interests_settings_page.dart';
import 'package:prasowka/screens/article_webview_screen.dart';
import 'package:prasowka/services/sports_service.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ScoresBar extends StatefulWidget {
  const ScoresBar({super.key});

  @override
  State<ScoresBar> createState() => _ScoresBarState();
}

class _ScoresBarState extends State<ScoresBar> {
  String? _lastSettingsHash;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.read<SettingsProvider>();
    if (settings.showSportsBar) {
      final newHash = "${settings.selectedLeagueIds.join()}_"
          "${settings.favoriteTeams.join()}_${settings.onlyFavoriteTeams}";
      final isFirstLoad = _lastSettingsHash == null;
      _lastSettingsHash = newHash;
      if (isFirstLoad) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.read<SportsProvider>().fetchEvents(
              favoriteKeywords: settings.favoriteTeams,
              onlyFavoriteTeams: settings.onlyFavoriteTeams,
              selectedLeagueIds: settings.selectedLeagueIds,
              force: true,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    // Reaktywne odświeżanie po zmianie ustawień
    final currentHash = "${settings.selectedLeagueIds.join()}_"
        "${settings.favoriteTeams.join()}_${settings.onlyFavoriteTeams}";
    if (settings.showSportsBar && _lastSettingsHash != currentHash) {
      _lastSettingsHash = currentHash;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<SportsProvider>().fetchEvents(
            favoriteKeywords: settings.favoriteTeams,
            onlyFavoriteTeams: settings.onlyFavoriteTeams,
            selectedLeagueIds: settings.selectedLeagueIds,
            force: true,
          );
        }
      });
    }

    if (!settings.showSportsBar) return const SizedBox.shrink();

    return Consumer<SportsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.events.isEmpty) {
          return _buildLoading();
        }

        // Buduj kafelki: eventy z API + fallback dla lig bez danych
        final tiles = _buildTiles(provider, settings);

        if (tiles.isEmpty) {
          return _buildEmptyState(context, settings);
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 85,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: tiles.length,
                itemBuilder: (context, index) => tiles[index],
              ),
            ),
            if (provider.lastFetch != null)
              Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.update, size: 10, color: Colors.grey.withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Text(
                      _formatLastUpdate(provider.lastFetch!),
                      style: TextStyle(fontSize: 9, color: Colors.grey.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  List<Widget> _buildTiles(SportsProvider provider, SettingsProvider settings) {
    final List<Widget> tiles = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    // 1. Grupuj eventy po statusie
    final liveMatches = <MatchEvent>[];
    final todayMatches = <MatchEvent>[];
    final upcomingMatches = <MatchEvent>[];
    final raceEvents = <RaceEvent>[];

    for (final event in provider.events) {
      if (event is MatchEvent) {
        final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
        if (event.status == EventStatus.live) {
          liveMatches.add(event);
        } else if (eventDate == today) {
          todayMatches.add(event);
        } else if (eventDate == tomorrow) {
          upcomingMatches.add(event);
        } else if (event.status == EventStatus.finished && eventDate == today) {
          todayMatches.add(event); // rozegrane dziś też pokazuj
        }
      } else if (event is RaceEvent) {
        raceEvents.add(event);
      }
    }

    // Sortuj: LIVE po minucie, dziś po godzinie
    liveMatches.sort((a, b) {
      final aMin = int.tryParse(a.time?.replaceAll("'", "") ?? '0') ?? 0;
      final bMin = int.tryParse(b.time?.replaceAll("'", "") ?? '0') ?? 0;
      return bMin.compareTo(aMin);
    });
    todayMatches.sort((a, b) => a.date.compareTo(b.date));
    upcomingMatches.sort((a, b) => a.date.compareTo(b.date));

    // 2. Dodaj kafelki LIVE (max 3)
    for (final event in liveMatches.take(3)) {
      tiles.add(_MatchScoreTile(
        event: event,
        onTap: () => _showMatchDetailBottomSheet(context, event, provider),
      ));
    }

    // 3. Dodaj kafelki dziś (max 5)
    for (final event in todayMatches.take(5)) {
      tiles.add(_MatchScoreTile(
        event: event,
        onTap: () => _showMatchDetailBottomSheet(context, event, provider),
      ));
    }

    // 4. Dodaj jutro (max 3)
    for (final event in upcomingMatches.take(3)) {
      tiles.add(_MatchScoreTile(
        event: event,
        onTap: () => _showMatchDetailBottomSheet(context, event, provider),
      ));
    }

    // 5. Dodaj wyścigi F1/WRC
    for (final event in raceEvents.take(2)) {
      tiles.add(_RaceTile(event: event));
    }

    // 6. Fallback tylko dla wybranych lig bez API
    final matchedLeagueIds = <String>{};
    for (final event in provider.events) {
      for (final id in settings.selectedLeagueIds) {
        final league = SportLeague.findById(id);
        if (league == null) continue;
        if (event is MatchEvent && _eventMatchesLeague(event, league)) {
          matchedLeagueIds.add(id);
        } else if (event is RaceEvent && league.sportType == event.type) {
          matchedLeagueIds.add(id);
        }
      }
    }

    for (final id in settings.selectedLeagueIds) {
      if (!matchedLeagueIds.contains(id)) {
        final league = SportLeague.findById(id);
        if (league != null) {
          tiles.add(_FallbackLeagueTile(league: league));
        }
      }
    }

    return tiles;
  }

  bool _eventMatchesLeague(MatchEvent event, SportLeague league) {
    final eventName = event.competition.toLowerCase();
    final leagueName = league.name.toLowerCase();

    if (eventName.contains(leagueName) || leagueName.contains(eventName)) return true;

    // Dopasowanie po kraju
    switch (league.countryCode) {
      case 'PL': return eventName.contains('pol');
      case 'GB': return eventName.contains('eng') || eventName.contains('premier');
      case 'IT': return eventName.contains('ita') || eventName.contains('serie a');
      case 'ES': return eventName.contains('esp') || eventName.contains('laliga') || eventName.contains('la liga');
      case 'DE': return eventName.contains('ger') || eventName.contains('bundesliga');
      case 'FR': return eventName.contains('fra') || eventName.contains('ligue');
      case 'NL': return eventName.contains('ned') || eventName.contains('eredivisie');
      case 'PT': return eventName.contains('por') || eventName.contains('liga portugal');
      case 'EU': return eventName.contains('champions') || eventName.contains('europa league') || eventName.contains('uefa');
      case 'US': return eventName.contains('nba') || eventName.contains('nhl') || eventName.contains('mlb') || eventName.contains('nfl') || eventName.contains('mls');
    }
    return false;
  }

  Widget _buildEmptyState(BuildContext context, SettingsProvider settings) {
    final hasLeagues = settings.selectedLeagueIds.isNotEmpty;
    final hasFavorites = settings.favoriteTeams.isNotEmpty;

    String title;
    String subtitle;
    IconData icon;

    if (hasLeagues || hasFavorites) {
      icon = Icons.search_off;
      title = 'Brak meczów';
      subtitle = hasFavorites
          ? 'Brak live/zaplanowanych meczów dla: ${settings.favoriteTeams.take(3).join(", ")}'
          : 'Brak meczów dla wybranych lig';
    } else {
      icon = Icons.sports_soccer;
      title = 'Wybierz ligi sportowe';
      subtitle = 'Kliknij, aby spersonalizować pasek';
    }

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InterestsSettingsPage())),
      child: Container(
        height: 85,
        width: double.infinity,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: Colors.orange),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.orange.withValues(alpha: 0.7)),
                textAlign: TextAlign.center,
              ),
            ),
            if (settings.favoriteTeams.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Ulubione: ${settings.favoriteTeams.join(", ")}',
                style: TextStyle(fontSize: 9, color: Colors.grey.withValues(alpha: 0.5)),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      height: 85,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 3,
        itemBuilder: (context, index) => Container(
          width: 175,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showMatchDetailBottomSheet(BuildContext context, MatchEvent event, SportsProvider sports) {
    final isScheduled = event.score.toLowerCase() == 'v' || event.status == EventStatus.scheduled;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MatchDetailSheet(event: event, isScheduled: isScheduled),
    );
  }

  String _formatDateShort(DateTime date) => "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}";
  String _formatTime(DateTime date) => "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

  String _formatLastUpdate(DateTime lastFetch) {
    final diff = DateTime.now().difference(lastFetch);
    if (diff.inMinutes < 1) return 'teraz';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min temu';
    if (diff.inHours < 24) return '${diff.inHours}h ${diff.inMinutes % 60}m temu';
    return '${_formatDateShort(lastFetch)} ${_formatTime(lastFetch)}';
  }
}

// ─── TILE: MECZ Z API ───

class _MatchScoreTile extends StatefulWidget {
  final MatchEvent event;
  final VoidCallback onTap;
  const _MatchScoreTile({required this.event, required this.onTap});

  @override
  State<_MatchScoreTile> createState() => _MatchScoreTileState();
}

class _MatchScoreTileState extends State<_MatchScoreTile> with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.event.status == EventStatus.live) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);
      _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    List<String> scoreParts = event.score.split(' - ');
    String homeScore = scoreParts.isNotEmpty ? scoreParts[0] : '';
    String awayScore = scoreParts.length > 1 ? scoreParts[1] : '';
    bool isScheduled = event.score.toLowerCase() == 'v' || event.status == EventStatus.scheduled;

    return Consumer<SportsProvider>(
      builder: (context, sports, _) {
        final isPinned = sports.isMatchPinned(event.id);
        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
          width: 175,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPinned ? AppTheme.accentForBrightness(context).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
              width: isPinned ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "${event.competition.toUpperCase()} | ${_formatDateLabel(event.date)}",
                      style: const TextStyle(fontSize: 7, color: Colors.grey, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.deferToChild,
                    onTap: () => sports.togglePinMatch(event.id),
                    child: Icon(
                      isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 14,
                      color: isPinned ? AppTheme.accentForBrightness(context) : Colors.grey.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (event.status == EventStatus.live)
                    _pulseAnimation != null
                        ? AnimatedBuilder(
                            animation: _pulseAnimation!,
                            builder: (context, child) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: _pulseAnimation!.value),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('LIVE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                            child: const Text('LIVE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                          )
                  else if (event.status == EventStatus.finished)
                    const Text('KONIEC', style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildTeamLogo(event.homeLogo, size: 12),
              const SizedBox(width: 6),
              Expanded(
                child: Text(event.homeTeam, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
              ),
              if (!isScheduled)
                Text(homeScore, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.accentForBrightness(context))),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildTeamLogo(event.awayLogo, size: 12),
              const SizedBox(width: 6),
              Expanded(
                child: Text(event.awayTeam, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
              ),
              if (!isScheduled)
                Text(awayScore, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.accentForBrightness(context))),
            ],
          ),
          if (isScheduled) ...[
            const Spacer(),
            Text(
              _formatTileTime(event),
              style: TextStyle(fontSize: 8, color: AppTheme.accentForBrightness(context), fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
      ),
    );
      },
    );
  }

  String _formatDateShort(DateTime date) => "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}";
  String _formatTime(DateTime date) => "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final matchDate = DateTime(date.year, date.month, date.day);

    if (matchDate == today) return _formatTime(date);
    if (matchDate == yesterday) return "WCZORAJ";
    return "${_formatDateShort(date)} ${_formatTime(date)}";
  }

  String _formatTileTime(MatchEvent event) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final matchDate = DateTime(event.date.year, event.date.month, event.date.day);

    if (matchDate == today) return _formatTime(event.date);
    if (matchDate == tomorrow) return "JUTRO ${_formatTime(event.date)}";
    return "${_formatDateShort(event.date)} ${_formatTime(event.date)}";
  }

  Widget _buildTeamLogo(String? url, {double size = 14}) {
    if (url == null || url.isEmpty) return Icon(Icons.shield, size: size, color: Colors.grey);
    return CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      placeholder: (context, url) => Icon(Icons.shield, size: size, color: Colors.grey),
      errorWidget: (context, url, error) => Icon(Icons.shield, size: size, color: Colors.grey),
    );
  }
}

// ─── TILE: WYŚCIG (F1 / WRC) ───

class _RaceTile extends StatelessWidget {
  final RaceEvent event;
  const _RaceTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 175,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                event.type == SportType.wrc ? 'WRC' : 'FORMULA 1',
                style: TextStyle(fontSize: 8, color: AppTheme.accentForBrightness(context), fontWeight: FontWeight.bold),
              ),
              Text(event.countryCode, style: const TextStyle(fontSize: 8, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          Text(event.raceName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(event.circuitName, style: const TextStyle(fontSize: 9, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Text(
            event.status == EventStatus.scheduled ? 'W TEN WEEKEND' : 'WYNIKI GP',
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

// ─── TILE: FALLBACK (brak danych z API) ───

class _FallbackLeagueTile extends StatelessWidget {
  final SportLeague league;
  const _FallbackLeagueTile({required this.league});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFlashscore(context),
      child: Container(
        width: 170,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accentForBrightness(context).withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(league.discipline.emoji, style: const TextStyle(fontSize: 16)),
                Icon(Icons.open_in_new, size: 12, color: AppTheme.accentForBrightness(context).withValues(alpha: 0.6)),
              ],
            ),
            const Spacer(),
            Text(league.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(league.country, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accentForBrightness(context).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'SPRAWDŹ NA FLASHSCORE',
                style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: AppTheme.accentForBrightness(context).withValues(alpha: 0.8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFlashscore(BuildContext context) {
    final url = league.flashscoreUrl ?? 'https://www.flashscore.com';
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ArticleWebViewScreen(url: url, title: league.name),
    ));
  }
}

// ─── BOTTOM SHEET: SZCZEGÓŁY MECZU Z STATYSTYKAMI ───

class _MatchDetailSheet extends StatefulWidget {
  final MatchEvent event;
  final bool isScheduled;
  const _MatchDetailSheet({required this.event, required this.isScheduled});

  @override
  State<_MatchDetailSheet> createState() => _MatchDetailSheetState();
}

class _MatchDetailSheetState extends State<_MatchDetailSheet> {
  MatchStats? _stats;
  bool _isLoadingStats = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isScheduled && widget.event.status != EventStatus.scheduled) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    setState(() { _isLoadingStats = true; });
    try {
      final service = SportsService();
      final stats = await service.fetchMatchStats(widget.event);
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() { _isLoadingStats = false; });
      }
    }
  }

  String _formatDateShort(DateTime date) => "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}";
  String _formatTime(DateTime date) => "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final matchDate = DateTime(date.year, date.month, date.day);
    if (matchDate == today) return _formatTime(date);
    if (matchDate == yesterday) return "WCZORAJ";
    return "${_formatDateShort(date)} ${_formatTime(date)}";
  }

  String _getFlashscoreLeagueUrl(MatchEvent event) {
    final competition = event.competition.toLowerCase();
    if (competition.contains('ekstraklasa')) return 'https://www.flashscore.pl/pilka-noza/polska/ekstraklasa/';
    if (competition.contains('premier league')) return 'https://www.flashscore.pl/pilka-noza/anglia/premier-league/';
    if (competition.contains('serie a')) return 'https://www.flashscore.pl/pilka-noza/wlochy/serie-a/';
    if (competition.contains('la liga') || competition.contains('laliga')) return 'https://www.flashscore.pl/pilka-noza/hiszpania/laliga/';
    if (competition.contains('bundesliga')) return 'https://www.flashscore.pl/pilka-noza/niemcy/bundesliga/';
    if (competition.contains('ligue 1')) return 'https://www.flashscore.pl/pilka-noza/francja/ligue-1/';
    if (competition.contains('eredivisie')) return 'https://www.flashscore.pl/pilka-noza/holandia/eredivisie/';
    if (competition.contains('liga portugal')) return 'https://www.flashscore.pl/pilka-noza/portugalia/liga-portugal/';
    if (competition.contains('champions league')) return 'https://www.flashscore.pl/pilka-noza/europa/ligue-of-champions/';
    if (competition.contains('europa league')) return 'https://www.flashscore.pl/pilka-noza/europa/europa-league/';
    if (competition.contains('super lig') || competition.contains('süper lig')) return 'https://www.flashscore.pl/pilka-noza/turcja/super-lig/';
    if (competition.contains('nba')) return 'https://www.flashscore.pl/koszykowka/usa/nba/';
    if (competition.contains('euroliga') || competition.contains('euroleague')) return 'https://www.flashscore.pl/koszykowka/europa/euroleague/';
    if (competition.contains('plk')) return 'https://www.flashscore.pl/koszykowka/polska/plk/';
    if (competition.contains('nhl')) return 'https://www.flashscore.pl/hokej/usa/nhl/';
    if (competition.contains('wta') || competition.contains('atp')) return 'https://www.flashscore.pl/tenis/';
    if (competition.contains('plusliga') || competition.contains('plus liga')) return 'https://www.flashscore.pl/siatkowka/polska/plusliga/';
    if (competition.contains('formula') || competition.contains('f1')) return 'https://www.flashscore.pl/motoryzacja/formula-1/';
    return 'https://www.flashscore.pl';
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    List<String> scoreParts = event.score.split(' - ');
    String homeScore = scoreParts.length >= 2 ? scoreParts[0] : '';
    String awayScore = scoreParts.length >= 2 ? scoreParts[1] : '';
    final hasStats = _stats != null && _stats!.rows.isNotEmpty;
    final showStatsSection = !widget.isScheduled && (hasStats || _isLoadingStats);
    final sheetHeight = widget.isScheduled
        ? MediaQuery.of(context).size.height * 0.45
        : (showStatsSection
            ? MediaQuery.of(context).size.height * 0.65
            : MediaQuery.of(context).size.height * 0.38);

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header: competition + status
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    event.competition.toUpperCase(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildStatusChip(event),
              ],
            ),
          ),
          // Date + time
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDateLabel(event.date),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
                if (event.status == EventStatus.live && event.time != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event.time!,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
          // Score
          if (homeScore.isNotEmpty && awayScore.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    flex: 3,
                    child: Text(event.homeTeam, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, textAlign: TextAlign.right),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$homeScore - $awayScore',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.accentForBrightness(context)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 3,
                    child: Text(event.awayTeam, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, textAlign: TextAlign.left),
                  ),
                ],
              ),
            ),
          const Divider(height: 16),
          // Stats section
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                if (widget.isScheduled)
                  _buildScheduledPlaceholder()
                else
                  _buildStatsContent(),
              ],
            ),
          ),
          // Flashscore button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  final leagueUrl = _getFlashscoreLeagueUrl(event);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ArticleWebViewScreen(
                      url: leagueUrl,
                      title: 'Flashscore — ${event.competition}',
                    ),
                  ));
                },
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('Pełne statystyki na Flashscore', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledPlaceholder() {
    return Column(
      children: [
        Icon(Icons.access_time, size: 32, color: Colors.grey.withValues(alpha: 0.4)),
        const SizedBox(height: 8),
        Text(
          'Statystyki dostępne po rozpoczęciu meczu',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStatsContent() {
    if (_isLoadingStats) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentForBrightness(context))),
            SizedBox(height: 12),
            Text('Ładowanie statystyk...', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    if (_stats != null && _stats!.rows.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _stats!.header,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: _stats!.rows.take(10).map((row) => _statRow(
                label: row.label,
                homeValue: row.homeValue,
                awayValue: row.awayValue,
              )).toList(),
            ),
          ),
        ],
      );
    }

    // Fallback - brak statystyk
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.bar_chart, size: 24, color: Colors.grey.withValues(alpha: 0.4)),
        const SizedBox(height: 6),
        Text(
          'Statystyki niedostępne',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildStatusChip(MatchEvent event) {
    if (event.status == EventStatus.live) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
      );
    } else if (event.status == EventStatus.finished) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('KONIEC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.accentForBrightness(context).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('WKRÓTCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentForBrightness(context))),
      );
    }
  }

  Widget _statRow({required String label, required String homeValue, required String awayValue}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), overflow: TextOverflow.ellipsis)),
          Expanded(
            child: Text(
              homeValue,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              awayValue,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
