import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/sport_event.dart';
import 'package:prasowka/models/sport_league.dart';
import 'package:prasowka/providers/sports_provider.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/screens/sport_settings_screen.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class ScoresBar extends StatefulWidget {
  const ScoresBar({super.key});

  @override
  State<ScoresBar> createState() => _ScoresBarState();
}

class _ScoresBarState extends State<ScoresBar> {
  String? _lastSettingsHash;

  void _checkAndRefresh(SettingsProvider settings) {
    final currentHash = "${settings.selectedLeagueIds.join()}_"
        "${settings.favoriteTeams.join()}_${settings.onlyFavoriteTeams}";

    if (_lastSettingsHash != currentHash) {
      _lastSettingsHash = currentHash;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SportsProvider>().fetchEvents(
          favoriteKeywords: settings.favoriteTeams,
          onlyFavoriteTeams: settings.onlyFavoriteTeams,
          selectedLeagueIds: settings.selectedLeagueIds,
          force: true,
        );
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = context.read<SettingsProvider>();
    if (settings.showSportsBar) {
      _checkAndRefresh(settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (!settings.showSportsBar) return const SizedBox.shrink();

    return Consumer<SportsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.events.isEmpty) {
          return _buildLoading();
        }

        if (provider.events.isEmpty) {
          return _buildEmptyState(context, settings.selectedLeagueIds.isEmpty);
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

  Widget _buildEmptyState(BuildContext context, bool noLeagues) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SportSettingsScreen())),
      child: Container(
        height: 100,
        width: double.infinity,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports_soccer, size: 28, color: Colors.grey),
            const SizedBox(height: 8),
            Text(
              noLeagues ? 'Wybierz ligi sportowe' : 'Brak meczów Twoich faworytów',
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Kliknij, aby spersonalizować pasek',
              style: TextStyle(fontSize: 10, color: Colors.grey.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
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
        title: const Text('DIAGNOSTYKA V4.5'),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "${event.competition.toUpperCase()} | ${_formatDateLabel(event.date)}",
                  style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (event.status == EventStatus.live)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                  child: const Text('LIVE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                )
              else if (event.status == EventStatus.finished)
                const Text('KONIEC', style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildTeamLogo(event.homeLogo),
              const SizedBox(width: 8),
              Expanded(
                child: Text(event.homeTeam, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
              ),
              if (!isScheduled)
                Text(homeScore, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.accentGold)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildTeamLogo(event.awayLogo),
              const SizedBox(width: 8),
              Expanded(
                child: Text(event.awayTeam, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
              ),
              if (!isScheduled)
                Text(awayScore, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.accentGold)),
            ],
          ),
          if (isScheduled) ...[
            const Spacer(),
            const Text("WKRÓTCE", style: TextStyle(fontSize: 8, color: AppTheme.accentGold, fontWeight: FontWeight.bold)),
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

    if (matchDate == today) return _formatTime(date);
    if (matchDate == yesterday) return "WCZORAJ";
    return "${_formatDateShort(date)} ${_formatTime(date)}";
  }

  Widget _buildTeamLogo(String? url) {
    if (url == null || url.isEmpty) return const Icon(Icons.shield, size: 14, color: Colors.grey);
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
              Text(
                event.type == SportType.wrc ? 'WRC' : 'FORMULA 1',
                style: const TextStyle(fontSize: 9, color: AppTheme.accentGold, fontWeight: FontWeight.bold),
              ),
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
