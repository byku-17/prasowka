import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prasowka/models/sport_event.dart';
import 'package:prasowka/models/sport_league.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SportsService {
  String get _theSportsDbKey => dotenv.env['THESPORTSDB_API_KEY'] ?? '3';

  /// Pobiera wydarzenia sportowe TYLKO dla wybranych lig
  Future<List<SportEvent>> fetchAllEvents({List<String>? selectedLeagueIds}) async {
    final List<SportEvent> allEvents = [];
    final List<Future<List<SportEvent>>> futures = [];

    // --- LOGIKA DATY (PODRÓŻ W CZASIE 2026 -> 2024) ---
    final now = DateTime.now();
    final DateTime referenceNow = now.year == 2026 
        ? DateTime(2024, now.month, now.day, now.hour, now.minute) 
        : now;
    
    debugPrint('Sowa Sports V8.5: Start (Reference: $referenceNow)');

    // Określ które ligi pobrać
    final leaguesToFetch = _getLeaguesToFetch(selectedLeagueIds);

    // Grupuj ligi po źródle danych
    final espnLeagues = <SportLeague>[];
    final tsdbLeagues = <SportLeague>[];
    SportLeague? f1League;

    for (final league in leaguesToFetch) {
      if (league.id == 'f1') {
        f1League = league;
      } else if (league.espnSport != null && league.espnLeague != null) {
        espnLeagues.add(league);
      } else if (league.tsdbLeagueId != null) {
        tsdbLeagues.add(league);
      }
    }

    // 1. ESPN leagues (NBA, NHL, MLB)
    final dateStr = referenceNow.toIso8601String().split('T')[0].replaceAll('-', '');
    
    final groupedEspn = <String, List<SportLeague>>{};
    for (final league in espnLeagues) {
      final key = '${league.espnSport}_${league.espnLeague}';
      groupedEspn.putIfAbsent(key, () => []).add(league);
    }
    
    for (final entry in groupedEspn.entries) {
      final league = entry.value.first;
      futures.add(_fetchEspnScoreboard(
        league.espnSport!,
        league.espnLeague!,
        league.sportType,
        league.name,
        dateStr,
      ));
    }

    // 2. TheSportsDB leagues
    for (final league in tsdbLeagues) {
      futures.add(_fetchTsdbLeague(league, referenceNow));
    }

    // 3. F1 (Dynamiczna data referencyjna)
    if (f1League != null) {
      futures.add(_fetchF1(referenceNow));
    }

    // 4. Tenis (TheSportsDB — Wymuszona data 2024)
    futures.add(_fetchTennis(referenceNow));

    // Zbieramy wyniki
    final results = await Future.wait(futures);
    for (var list in results) {
      allEvents.addAll(list);
    }

    // Usuwamy duplikaty
    final Map<String, SportEvent> unique = {};
    for (var e in allEvents) { unique[e.id] = e; }

    debugPrint('Sowa Sports V8.5: Zakończono. Łącznie unikalnych: ${unique.length}');
    return unique.values.toList();
  }

  List<SportLeague> _getLeaguesToFetch(List<String>? selectedLeagueIds) {
    if (selectedLeagueIds == null || selectedLeagueIds.isEmpty) {
      // Domyślnie wszystkie ligi piłkarskie + top ligi USA
      return SportLeague.allLeagues.where((l) => l.hasApi).toList();
    }
    return selectedLeagueIds
        .map((id) => SportLeague.findById(id))
        .whereType<SportLeague>()
        .where((l) => l.hasApi)
        .toList();
  }

  Future<List<SportEvent>> _fetchEspnScoreboard(String sport, String league, SportType type, String competition, String dateStr) async {
    try {
      final url = 'https://site.api.espn.com/apis/site/v2/sports/$sport/$league/scoreboard?dates=$dateStr';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List events = data['events'] ?? [];
        return events.map((e) {
          final competitions = e['competitions'] ?? [];
          final comp = competitions.isNotEmpty ? competitions[0] : null;
          final competitors = comp?['competitors'] ?? [];

          String homeTeam = '?';
          String awayTeam = '?';
          String homeScore = '0';
          String awayScore = '0';
          String? homeLogo;
          String? awayLogo;

          for (var c in competitors) {
            final isHome = c['homeAway'] == 'home';
            final team = c['team'] ?? {};
            final score = c['score'] ?? '0';
            if (isHome) {
              homeTeam = team['displayName'] ?? team['shortDisplayName'] ?? '?';
              homeScore = score;
              homeLogo = team['logo'];
            } else {
              awayTeam = team['displayName'] ?? team['shortDisplayName'] ?? '?';
              awayScore = score;
              awayLogo = team['logo'];
            }
          }

          final statusType = e['status']?['type']?['name'] ?? '';
          EventStatus status;
          switch (statusType) {
            case 'STATUS_FINAL': status = EventStatus.finished; break;
            case 'STATUS_IN_PROGRESS': status = EventStatus.live; break;
            default: status = EventStatus.scheduled;
          }

          return MatchEvent(
            id: '${type.name}_${e['id']}',
            type: type,
            date: DateTime.parse(e['date']).toLocal(),
            status: status,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            score: "$homeScore - $awayScore",
            competition: competition,
            homeLogo: homeLogo,
            awayLogo: awayLogo,
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<SportEvent>> _fetchTsdbLeague(SportLeague league, DateTime referenceNow) async {
    try {
      final results = await Future.wait([
        http.get(Uri.parse('https://www.thesportsdb.com/api/v1/json/$_theSportsDbKey/eventslastleague.php?id=${league.tsdbLeagueId}')),
        http.get(Uri.parse('https://www.thesportsdb.com/api/v1/json/$_theSportsDbKey/eventsnextleague.php?id=${league.tsdbLeagueId}')),
      ]);

      final List<SportEvent> allLeagueEvents = [];

      for (var response in results) {
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List events = data['events'] ?? data['results'] ?? [];
          for (var e in events) {
            DateTime? matchDateTime;
            try {
              final datePart = e['dateEvent'];
              final timePart = e['strTime'] ?? '00:00:00';
              matchDateTime = DateTime.parse("${datePart}T$timePart");
            } catch (_) {
              try { matchDateTime = DateTime.parse(e['dateEvent']); } catch (_) { continue; }
            }

            if (matchDateTime.difference(referenceNow).inDays.abs() <= 7) {
              allLeagueEvents.add(MatchEvent(
                id: 'tsdb_fb_${e['idEvent']}',
                type: league.sportType,
                date: matchDateTime.toLocal(),
                status: _mapTsdbStatus(e['strStatus']),
                homeTeam: e['strHomeTeam'] ?? '?',
                awayTeam: e['strAwayTeam'] ?? '?',
                score: e['intHomeScore'] != null ? "${e['intHomeScore']} - ${e['intAwayScore']}" : "vs",
                competition: league.name,
                homeLogo: e['strHomeTeamBadge'],
                awayLogo: e['strAwayTeamBadge'],
              ));
            }
          }
        }
      }
      return allLeagueEvents;
    } catch (_) {}
    return [];
  }

  Future<List<SportEvent>> _fetchF1(DateTime referenceNow) async {
    try {
      final year = referenceNow.year;
      final response = await http.get(Uri.parse('https://api.openf1.org/v1/sessions?year=$year')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List sessions = data is List ? data : [];
        final threshold = referenceNow.toUtc();

        final races = sessions
            .where((s) => s['session_type'] == 'Race')
            .toList()
          ..sort((a, b) => DateTime.parse(a['date_start']).compareTo(DateTime.parse(b['date_start'])));
        
        final nextRace = races.firstWhere((s) => DateTime.parse(s['date_start']).isAfter(threshold), orElse: () => races.last);

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

  Future<List<SportEvent>> _fetchTennis(DateTime referenceNow) async {
    try {
      final dateStr = referenceNow.toIso8601String().split('T')[0];
      final url = 'https://www.thesportsdb.com/api/v1/json/$_theSportsDbKey/eventsday.php?d=$dateStr&s=Tennis';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List events = data['events'] ?? [];
        return events.map((e) {
          DateTime? matchDateTime;
          try {
            matchDateTime = DateTime.parse("${e['dateEvent']}T${e['strTime']}");
          } catch (_) {
            matchDateTime = DateTime.parse(e['dateEvent']);
          }
          return MatchEvent(
            id: 'tennis_${e['idEvent']}',
            type: SportType.tennis,
            date: matchDateTime.toLocal(),
            status: e['strStatus'] == 'FT' ? EventStatus.finished : EventStatus.scheduled,
            homeTeam: e['strHomeTeam'] ?? '?',
            awayTeam: e['strAwayTeam'] ?? '?',
            score: e['intHomeScore'] != null ? "${e['intHomeScore']} - ${e['intAwayScore']}" : "vs",
            competition: e['strLeague'] ?? 'Tennis',
            homeLogo: e['strHomeTeamBadge'],
            awayLogo: e['strAwayTeamBadge']
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  EventStatus _mapTsdbStatus(String? status) {
    if (status == 'FT') return EventStatus.finished;
    if (status == 'NS' || status == 'PST') return EventStatus.scheduled;
    return EventStatus.live;
  }
}
