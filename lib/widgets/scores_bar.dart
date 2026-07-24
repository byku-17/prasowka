import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/sport_event.dart';
import 'package:prasowka/providers/sports_provider.dart';
import 'package:prasowka/providers/settings_provider.dart';
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
  void initState() {
    super.initState();
  }

  void _checkAndRefresh(SettingsProvider settings) {
    final currentHash = "${settings.enabledSports.join()}${settings.enabledLeagues.join()}${settings.onlyFavoriteTeams}${settings.favoriteTeams.join()}";
    
    if (_lastSettingsHash != currentHash) {
      _lastSettingsHash = currentHash;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SportsProvider>().fetchEvents(
          favoriteKeywords: settings.favoriteTeams,
          enabledSports: settings.enabledSports,
          enabledLeagues: settings.enabledLeagues,
          onlyFavoriteTeams: settings.onlyFavoriteTeams,
          force: true,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (!settings.showSportsBar) return const SizedBox.shrink();

    _checkAndRefresh(settings);

    return Consumer<SportsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.events.isEmpty) {
          return _buildLoading();
        }
        
        if (provider.events.isEmpty) {
          return GestureDetector(
            onLongPress: () => _showDebugDialog(context, provider.debugLogs),
            child: Container(
              height: 60,
              width: double.infinity,
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: const Text(
                'Brak meczów dla wybranych filtrów (Przytrzymaj by sprawdzić)',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          );
        }

        return Container(
          height: 115,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: provider.events.length,
            itemBuilder: (context, index) {
              final event = provider.events[index];
              if (event is MatchEvent) {
                return _MatchScoreTile(event: event);
              } else if (event is RaceEvent) {
                return _RaceTile(event: event);
              }
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }

  Widget _buildLoading() {
    return Container(
      height: 115,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 3,
        itemBuilder: (context, index) => Container(
          width: 160,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showDebugDialog(BuildContext context, List<String> logs) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('DIAGNOSTYKA SOWY'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: logs.length,
            itemBuilder: (context, i) => Text(
              logs[i],
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ZAMKNIJ')),
        ],
      ),
    );
  }
}

class _MatchScoreTile extends StatelessWidget {
  final MatchEvent event;
  const _MatchScoreTile({required this.event});

  @override
  Widget build(BuildContext context) {
    // Rozdzielamy wynik "2 - 1" na części. Jeśli mecz się nie zaczął (v), dajemy puste.
    List<String> scoreParts = event.score.split(' - ');
    String homeScore = scoreParts.isNotEmpty ? scoreParts[0] : '';
    String awayScore = scoreParts.length > 1 ? scoreParts[1] : '';
    bool isScheduled = event.score.toLowerCase() == 'v' || event.status == EventStatus.scheduled;

    return Container(
      width: 200,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Nagłówek: Liga i Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "${_getSportLabel(event.type)}: ${event.competition.toUpperCase()} | ${_formatDateLabel(event.date)}",
                  style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (event.status == EventStatus.live)
                Row(
                  children: [
                    Text(event.time ?? '', style: const TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                      child: const Text('LIVE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                )
              else if (event.status == EventStatus.finished)
                const Text('KONIEC', style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          
          // Drużyna Gospodarzy
          Row(
            children: [
              _buildTeamLogo(event.homeLogo),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.homeTeam,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isScheduled)
                Text(
                  homeScore,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.accentGold),
                ),
            ],
          ),
          const SizedBox(height: 6),
          
          // Drużyna Gości
          Row(
            children: [
              _buildTeamLogo(event.awayLogo),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  event.awayTeam,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isScheduled)
                Text(
                  awayScore,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.accentGold),
                ),
            ],
          ),
          
          if (isScheduled) ...[
            const Spacer(),
            const Text(
              "NADCHODZĄCE",
              style: TextStyle(fontSize: 8, color: AppTheme.accentGold, fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateShort(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}";
  }

  String _formatTime(DateTime date) {
    return "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
  }

  String _formatDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final matchDate = DateTime(date.year, date.month, date.day);

    if (matchDate == today) {
      return _formatTime(date);
    } else if (matchDate == yesterday) {
      return "WCZORAJ";
    } else {
      return "${_formatDateShort(date)} ${_formatTime(date)}";
    }
  }

  String _getSportLabel(SportType type) {
    switch (type) {
      case SportType.football: return 'PIŁKA';
      case SportType.nba: return 'NBA';
      case SportType.nhl: return 'NHL';
      case SportType.mlb: return 'MLB';
      case SportType.nfl: return 'NFL';
      case SportType.tennis: return 'TENIS';
      case SportType.volleyball: return 'SIATKÓWKA';
      case SportType.handball: return 'RĘCZNA';
      default: return '';
    }
  }

  Widget _buildTeamLogo(String? url) {
    if (url == null) return const Icon(Icons.shield, size: 14, color: Colors.grey);
    return CachedNetworkImage(
      imageUrl: url,
      width: 14,
      height: 14,
      placeholder: (context, url) => const Icon(Icons.shield, size: 14, color: Colors.grey),
      errorWidget: (context, url, error) => const Icon(Icons.shield, size: 14, color: Colors.grey),
    );
  }
}

class _RaceTile extends StatelessWidget {
  final RaceEvent event;
  const _RaceTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              const Text('FORMULA 1', style: TextStyle(fontSize: 9, color: AppTheme.accentGold, fontWeight: FontWeight.bold)),
              Text(event.countryCode, style: const TextStyle(fontSize: 9, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          Text(event.raceName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(event.circuitName, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Text(
            event.status == EventStatus.scheduled ? 'W TEN WEEKEND' : 'WYNIKI GP',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
