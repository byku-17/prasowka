import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prasowka/models/sport_event.dart';
import 'package:prasowka/models/sport_league.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SportsService {
  String get _sportDbKey => dotenv.env['SPORTDB_API_KEY'] ?? '';
  String get _theSportsDbKey => dotenv.env['THESPORTSDB_API_KEY'] ?? '3';

  static const _espnUserAgent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15';

  Future<List<SportEvent>> fetchAllEvents({List<String>? selectedLeagueIds}) async {
    final List<SportEvent> allEvents = [];
    final List<Future<List<SportEvent>>> futures = [];

    final now = DateTime.now();
    final DateTime referenceNow = now.year == 2026
        ? DateTime(2024, now.month, now.day, now.hour, now.minute)
        : now;

    debugPrint('Prasówka Sports V9.0: Start (Reference: $referenceNow)');

    final leaguesToFetch = _getLeaguesToFetch(selectedLeagueIds);
    final dateStr = referenceNow.toIso8601String().split('T')[0].replaceAll('-', '');

    // 1. SportDB.dev — primary source (if key available)
    if (_sportDbKey.isNotEmpty) {
      futures.add(_fetchSportDbLive(referenceNow));
    }

    // 2. ESPN — fallback for mobile devices (works from residential IPs)
    final espnLeagues = leaguesToFetch.where((l) =>
        l.espnSport != null && l.espnLeague != null).toList();

    if (espnLeagues.isNotEmpty) {
      final groupedEspn = <String, List<SportLeague>>{};
      for (final league in espnLeagues) {
        final key = '${league.espnSport}_${league.espnLeague}';
        groupedEspn.putIfAbsent(key, () => []).add(league);
      }
      for (final entry in groupedEspn.entries) {
        final l = entry.value.first;
        futures.add(_fetchEspnScoreboard(l.espnSport!, l.espnLeague!, l.sportType, l.name, dateStr, referenceNow));
      }
    }

    // 3. TheSportsDB — dla lig z tsdbLeagueId (football + tenis)
    final tdbLeagues = leaguesToFetch.where((l) => l.tsdbLeagueId != null).toList();
    if (tdbLeagues.isNotEmpty) {
      for (final league in tdbLeagues) {
        futures.add(_fetchTsdLeague(league, referenceNow));
      }
    }

    // 4. F1 — always from OpenF1
    final hasF1 = leaguesToFetch.any((l) => l.id == 'f1');
    if (hasF1) futures.add(_fetchF1(referenceNow));

    final results = await Future.wait(futures);
    for (var list in results) {
      allEvents.addAll(list);
    }

    // Deduplicate by ID
    final Map<String, SportEvent> unique = {};
    for (var e in allEvents) { unique[e.id] = e; }

    debugPrint('Prasówka Sports V9.0: Zakończono. Unikalnych: ${unique.length}');
    return unique.values.toList();
  }

  List<SportLeague> _getLeaguesToFetch(List<String>? selectedLeagueIds) {
    if (selectedLeagueIds == null || selectedLeagueIds.isEmpty) {
      return SportLeague.allLeagues.where((l) => l.hasApi).toList();
    }
    return selectedLeagueIds
        .map((id) => SportLeague.findById(id))
        .whereType<SportLeague>()
        .where((l) => l.hasApi)
        .toList();
  }

  // ─── SPORTDB.DEV + FLASHSCORE (primary) ───

  Future<List<SportEvent>> _fetchSportDbLive(DateTime referenceNow) async {
    if (_sportDbKey.isEmpty) return [];
    final List<SportEvent> result = [];

    try {
      final response = await http.get(
        Uri.parse('https://api.sportdb.dev/api/flashscore/football/live'),
        headers: {'X-API-Key': _sportDbKey, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List matches = json.decode(response.body);

        for (var m in matches) {
          try {
            final eventStage = (m['eventStage'] ?? '').toString();
            final homeName = m['homeName'] ?? '?';
            final awayName = m['awayName'] ?? '?';
            final homeLogo = m['homeLogo'];
            final awayLogo = m['awayLogo'];
            final eventId = m['eventId'] ?? '';
            final tournament = m['tournamentName'] ?? 'Football';

            EventStatus status;
            if (eventStage == 'LIVE' || eventStage == 'IN_PLAY') {
              status = EventStatus.live;
            } else if (eventStage == 'FINISHED' || eventStage == 'FT' || eventStage == 'ENDED') {
              status = EventStatus.finished;
            } else {
              status = EventStatus.scheduled;
            }

            final dateStr = m['startDateTimeUtc'] ?? m['startDate'] ?? '';

            final score = _parseSportDbScore(m);

            result.add(MatchEvent(
              id: 'sportdb_fb_$eventId',
              type: SportType.football,
              date: DateTime.tryParse(dateStr) ?? referenceNow,
              status: status,
              homeTeam: homeName,
              awayTeam: awayName,
              score: score,
              competition: tournament,
              homeLogo: homeLogo,
              awayLogo: awayLogo,
              time: m['gameTime'],
            ));
          } catch (_) {}
        }
      }
    } catch (_) {}

    // Also fetch basketball
    try {
      final response = await http.get(
        Uri.parse('https://api.sportdb.dev/api/flashscore/basketball/live'),
        headers: {'X-API-Key': _sportDbKey, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List matches = json.decode(response.body);
        for (var m in matches) {
          try {
            final eventStage = (m['eventStage'] ?? '').toString();
            final eventId = m['eventId'] ?? '';
            EventStatus status = eventStage == 'LIVE' ? EventStatus.live
                : (eventStage == 'FINISHED' ? EventStatus.finished : EventStatus.scheduled);

            result.add(MatchEvent(
              id: 'sportdb_bb_$eventId',
              type: SportType.nba,
              date: DateTime.tryParse(m['startDateTimeUtc'] ?? '') ?? referenceNow,
              status: status,
              homeTeam: m['homeName'] ?? '?',
              awayTeam: m['awayName'] ?? '?',
              score: _parseSportDbScore(m),
              competition: m['tournamentName'] ?? 'Basketball',
              homeLogo: m['homeLogo'],
              awayLogo: m['awayLogo'],
              time: m['gameTime'],
            ));
          } catch (_) {}
        }
      }
    } catch (_) {}

    // Also fetch tennis
    try {
      final response = await http.get(
        Uri.parse('https://api.sportdb.dev/api/flashscore/tennis/live'),
        headers: {'X-API-Key': _sportDbKey, 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List matches = json.decode(response.body);
        for (var m in matches) {
          try {
            final eventStage = (m['eventStage'] ?? '').toString();
            final eventId = m['eventId'] ?? '';
            EventStatus status = eventStage == 'LIVE' ? EventStatus.live
                : (eventStage == 'FINISHED' ? EventStatus.finished : EventStatus.scheduled);

            result.add(MatchEvent(
              id: 'sportdb_tn_$eventId',
              type: SportType.tennis,
              date: DateTime.tryParse(m['startDateTimeUtc'] ?? '') ?? referenceNow,
              status: status,
              homeTeam: m['homeName'] ?? '?',
              awayTeam: m['awayName'] ?? '?',
              score: _parseSportDbScore(m),
              competition: m['tournamentName'] ?? 'Tennis',
              homeLogo: m['homeLogo'],
              awayLogo: m['awayLogo'],
              time: m['gameTime'],
            ));
          } catch (_) {}
        }
      }
    } catch (_) {}

    return result;
  }

  String _parseSportDbScore(Map m) {
    final homeScore = m['homeScore'] ?? m['intHomeScore'] ?? m['homeGoals'];
    final awayScore = m['awayScore'] ?? m['intAwayScore'] ?? m['awayGoals'];
    if (homeScore != null && awayScore != null) {
      return '$homeScore - $awayScore';
    }
    final result = m['result'] ?? m['score'] ?? m['resultText'];
    if (result != null && result.toString().isNotEmpty && result != 'v') {
      return result.toString();
    }
    return 'v';
  }

  // ─── MATCH STATS (ESPN Summary) ───

  String? _espnSportLeague(SportType type) {
    switch (type) {
      case SportType.football: return 'soccer';
      case SportType.nba: return 'basketball';
      case SportType.nhl: return 'hockey';
      case SportType.nfl: return 'football';
      case SportType.mlb: return 'baseball';
      default: return null;
    }
  }

  String _espnDefaultLeague(SportType type) {
    switch (type) {
      case SportType.nba: return 'nba';
      case SportType.nhl: return 'nhl';
      case SportType.nfl: return 'nfl';
      case SportType.mlb: return 'mlb';
      default: return '';
    }
  }

  String? _findEspnLeagueForCompetition(String competition, SportType type) {
    final c = competition.toLowerCase();
    if (type == SportType.football) {
      if (c.contains('premier league')) return 'eng.1';
      if (c.contains('serie a')) return 'ita.1';
      if (c.contains('la liga') || c.contains('laliga')) return 'esp.1';
      if (c.contains('bundesliga')) return 'ger.1';
      if (c.contains('ligue 1')) return 'fra.1';
      if (c.contains('eredivisie')) return 'ned.1';
      if (c.contains('liga portugal')) return 'por.1';
      if (c.contains('ekstraklasa')) return 'pol.1';
      if (c.contains('champions league')) return 'uefa.champions';
      if (c.contains('europa league')) return 'uefa.europa';
      if (c.contains('super lig') || c.contains('süper lig')) return 'tur.1';
      if (c.contains('mls')) return 'usa.1';
      if (c.contains('superliga')) return 'den.1';
    }
    return _espnDefaultLeague(type);
  }

  Future<MatchStats?> fetchMatchStats(MatchEvent event) async {
    final espnSport = _espnSportLeague(event.type);
    if (espnSport == null) return null;

    String espnLeague = _findEspnLeagueForCompetition(event.competition, event.type) ?? '';
    if (espnLeague.isEmpty) return null;

    String? espnEventId;

    if (event.id.startsWith('espn_')) {
      espnEventId = event.id.split('_').last;
    } else {
      espnEventId = await _searchEspnEventId(espnSport, espnLeague, event);
    }

    if (espnEventId == null || espnEventId.isEmpty) return null;

    return _fetchEspnSummary(espnSport, espnLeague, espnEventId);
  }

  Future<String?> _searchEspnEventId(String sport, String league, MatchEvent target) async {
    final now = DateTime.now();
    final dates = [
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}',
      '${now.subtract(const Duration(days: 1)).year}${now.subtract(const Duration(days: 1)).month.toString().padLeft(2, '0')}${now.subtract(const Duration(days: 1)).day.toString().padLeft(2, '0')}',
    ];

    for (final dateStr in dates) {
      try {
        final url = 'https://site.api.espn.com/apis/site/v2/sports/$sport/$league/scoreboard?dates=$dateStr';
        final response = await http.get(Uri.parse(url), headers: {
          'User-Agent': _espnUserAgent,
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List events = data['events'] ?? [];

          for (var e in events) {
            try {
              final comp = (e['competitions'] as List).first;
              final competitors = comp['competitors'] as List;
              String homeName = '', awayName = '';
              for (var c in competitors) {
                final team = c['team'] ?? {};
                if (c['homeAway'] == 'home') {
                  homeName = (team['displayName'] ?? team['shortDisplayName'] ?? '').toLowerCase();
                } else {
                  awayName = (team['displayName'] ?? team['shortDisplayName'] ?? '').toLowerCase();
                }
              }
              final targetHome = target.homeTeam.toLowerCase();
              final targetAway = target.awayTeam.toLowerCase();
              if (_teamNamesMatch(homeName, targetHome) && _teamNamesMatch(awayName, targetAway)) {
                return e['id']?.toString();
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }
    return null;
  }

  bool _teamNamesMatch(String apiName, String targetName) {
    if (apiName.isEmpty || targetName.isEmpty) return false;
    if (apiName.contains(targetName) || targetName.contains(apiName)) return true;
    final apiWords = apiName.split(RegExp(r'\s+'));
    for (final word in apiWords) {
      if (word.length >= 4 && targetName.contains(word)) return true;
    }
    final targetWords = targetName.split(RegExp(r'\s+'));
    for (final word in targetWords) {
      if (word.length >= 4 && apiName.contains(word)) return true;
    }
    return false;
  }

  Future<MatchStats?> _fetchEspnSummary(String sport, String league, String eventId) async {
    try {
      final url = 'https://site.api.espn.com/apis/site/v2/sports/$sport/$league/summary?event=$eventId';
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': _espnUserAgent,
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<MatchStatRow> rows = [];

        // Format 1: data['statistics'] as List of {name, labels, values}
        final stats = data['statistics'];
        if (stats is List) {
          for (var group in stats) {
            if (group is Map) {
              final innerStats = group['stats'] ?? group['statistics'];
              if (innerStats is List) {
                _parseStatList(innerStats, rows);
              } else {
                _parseSingleStat(group, rows);
              }
            }
          }
        } else if (stats is Map) {
          // Format 2: data['statistics']['groups'] or data['statistics']['stats']
          final groups = stats['groups'] ?? stats['stats'];
          if (groups is List) {
            _parseStatList(groups, rows);
          }
          // Format 3: flat stats in map values
          for (var entry in stats.entries) {
            if (entry.value is List) {
              _parseStatList(entry.value, rows);
            }
          }
        }

        // Format 4: data['boxscore']['statistics']
        final boxscore = data['boxscore'];
        if (boxscore is Map) {
          final boxStats = boxscore['statistics'];
          if (boxStats is List) {
            _parseStatList(boxStats, rows);
          } else if (boxStats is Map) {
            for (var entry in boxStats.entries) {
              if (entry.value is List) _parseStatList(entry.value, rows);
            }
          }
        }

        // Format 5: data['keyStats']['categories'] (basketball)
        final keyStats = data['keyStats'];
        if (keyStats is Map) {
          final categories = keyStats['categories'];
          if (categories is List) _parseStatList(categories, rows);
        }

        if (rows.isNotEmpty) {
          return MatchStats(header: 'STATYSTYKI MECZU', rows: rows);
        }
      }
    } catch (_) {}
    return null;
  }

  void _parseStatList(List list, List<MatchStatRow> rows) {
    for (var item in list) {
      if (item is Map) {
        final labels = item['labels'] ?? [];
        final values = item['values'] ?? [];
        final name = item['name'] ?? item['label'] ?? '';
        final teams = item['teams'] ?? [];

        if (labels is List && values is List && labels.length >= 2 && values.length >= 2) {
          rows.add(MatchStatRow(
            label: name.toString(),
            homeValue: values[0].toString(),
            awayValue: values[1].toString(),
          ));
        } else if (teams is List && teams.length >= 2) {
          rows.add(MatchStatRow(
            label: name.toString(),
            homeValue: (teams[0]['displayValue'] ?? teams[0]['value'] ?? '—').toString(),
            awayValue: (teams[1]['displayValue'] ?? teams[1]['value'] ?? '—').toString(),
          ));
        }

        final innerStats = item['stats'];
        if (innerStats is List) {
          _parseStatList(innerStats, rows);
        }
      }
    }
  }

  void _parseSingleStat(Map item, List<MatchStatRow> rows) {
    final name = item['name'] ?? item['label'] ?? '';
    final labels = item['labels'] ?? [];
    final values = item['values'] ?? [];
    final teams = item['teams'] ?? [];

    if (labels is List && values is List && labels.length >= 2 && values.length >= 2) {
      rows.add(MatchStatRow(
        label: name.toString(),
        homeValue: values[0].toString(),
        awayValue: values[1].toString(),
      ));
    } else if (teams is List && teams.length >= 2) {
      rows.add(MatchStatRow(
        label: name.toString(),
        homeValue: (teams[0]['displayValue'] ?? teams[0]['value'] ?? '—').toString(),
        awayValue: (teams[1]['displayValue'] ?? teams[1]['value'] ?? '—').toString(),
      ));
    }
  }

  // ─── ESPN (fallback for mobile) ───

  Future<List<SportEvent>> _fetchEspnScoreboard(String sport, String league, SportType type, String competition, String dateStr, DateTime referenceNow) async {
    try {
      final url = 'https://site.api.espn.com/apis/site/v2/sports/$sport/$league/scoreboard?dates=$dateStr';
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': _espnUserAgent,
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List events = data['events'] ?? [];
        final List<SportEvent> result = [];

        for (var e in events) {
          try {
            final comp = (e['competitions'] as List).first;
            final competitors = comp['competitors'] as List;
            String homeTeam = '?', awayTeam = '?', homeScore = '0', awayScore = '0';
            String? homeLogo, awayLogo;

            for (var c in competitors) {
              final isHome = c['homeAway'] == 'home';
              final team = c['team'] ?? {};
              if (isHome) {
                homeTeam = team['displayName'] ?? '?';
                homeScore = c['score'] ?? '0';
                homeLogo = team['logo'];
              } else {
                awayTeam = team['displayName'] ?? '?';
                awayScore = c['score'] ?? '0';
                awayLogo = team['logo'];
              }
            }

            final statusType = e['status']?['type']?['name'] ?? '';
            final displayClock = e['status']?['displayClock'];

            if (statusType == 'STATUS_SCHEDULED' || statusType == 'STATUS_PRE') {
              try {
                final eventDate = DateTime.parse(e['date']);
                if (eventDate.isAfter(referenceNow.add(const Duration(days: 7)))) continue;
              } catch (_) {}
            }

            EventStatus status = statusType == 'STATUS_FINAL'
                ? EventStatus.finished
                : (statusType == 'STATUS_IN_PROGRESS' ? EventStatus.live : EventStatus.scheduled);

            result.add(MatchEvent(
              id: 'espn_${type.name}_${e['id']}',
              type: type,
              date: DateTime.parse(e['date']).toLocal(),
              status: status,
              homeTeam: homeTeam,
              awayTeam: awayTeam,
              score: "$homeScore - $awayScore",
              competition: competition,
              homeLogo: homeLogo,
              awayLogo: awayLogo,
              time: (status == EventStatus.live && displayClock != null) ? displayClock : null,
            ));
          } catch (_) {}
        }
        return result;
      }
    } catch (_) {}
    return [];
  }

  // ─── OPENF1 ───

  Future<List<SportEvent>> _fetchF1(DateTime referenceNow) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.openf1.org/v1/sessions?year=${referenceNow.year}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List sessions = data is List ? data : [];
        final races = sessions.where((s) => s['session_type'] == 'Race').toList()
          ..sort((a, b) => DateTime.parse(a['date_start']).compareTo(DateTime.parse(b['date_start'])));
        final nextRace = races.firstWhere(
          (s) => DateTime.parse(s['date_start']).isAfter(referenceNow.toUtc()),
          orElse: () => races.isNotEmpty ? races.last : null,
        );
        if (nextRace == null) return [];
        final meeting = nextRace['meeting'] ?? {};
        return [RaceEvent(
          id: 'f1_${nextRace['session_key']}',
          type: SportType.f1,
          date: DateTime.parse(nextRace['date_start']).toLocal(),
          status: EventStatus.scheduled,
          raceName: nextRace['session_name'] ?? meeting['meeting_name'] ?? 'F1 Race',
          circuitName: meeting['circuit_short_name'] ?? '',
          countryCode: meeting['country_code'] ?? '',
        )];
      }
    } catch (_) {}
    return [];
  }

  // ─── THE_SPORTSDB (football + tennis per league) ───

  Future<List<SportEvent>> _fetchTsdLeague(SportLeague league, DateTime referenceNow) async {
    try {
      final dateStr = referenceNow.toIso8601String().split('T')[0];
      final sport = league.sportType == SportType.tennis ? 'Tennis' : 'Soccer';
      final url = 'https://www.thesportsdb.com/api/v1/json/$_theSportsDbKey/eventsday.php?d=$dateStr&s=$sport';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List events = data['events'] ?? [];
        final List<SportEvent> result = [];

        for (var e in events) {
          final eventLeague = (e['strLeague'] ?? '').toString().toLowerCase();
          if (!eventLeague.contains(league.name.toLowerCase()) &&
              !league.name.toLowerCase().contains(eventLeague)) {
            continue;
          }

          DateTime? matchDate;
          try {
            matchDate = DateTime.parse("${e['dateEvent']}T${e['strTime'] ?? '00:00:00'}");
          } catch (_) {
            try { matchDate = DateTime.parse(e['dateEvent']); } catch (_) { continue; }
          }
          result.add(MatchEvent(
            id: 'tsdb_${league.id}_${e['idEvent']}',
            type: league.sportType,
            date: matchDate.toLocal(),
            status: e['strStatus'] == 'FT' ? EventStatus.finished : EventStatus.scheduled,
            homeTeam: e['strHomeTeam'] ?? '?',
            awayTeam: e['strAwayTeam'] ?? '?',
            score: e['intHomeScore'] != null ? "${e['intHomeScore']} - ${e['intAwayScore']}" : "v",
            competition: e['strLeague'] ?? league.name,
            homeLogo: e['strHomeTeamBadge'],
            awayLogo: e['strAwayTeamBadge'],
          ));
        }
        return result;
      }
    } catch (_) {}
    return [];
  }
}
