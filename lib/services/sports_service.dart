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

    final now = DateTime.now();
    debugPrint('Sowa Sports V8.0: Start (Real: $now, Selected: ${selectedLeagueIds?.length ?? "all"})');

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

    // 1. ESPN leagues (wszystkie ligi ESPN w jednym zapytaniu per sport)
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
      ));
    }

    // 2. TheSportsDB leagues (każda liga osobno)
    for (final league in tsdbLeagues) {
      futures.add(_fetchTsdbLeague(league));
    }

    // 3. F1
    if (f1League != null) {
      futures.add(_fetchF1());
    }

    // Zbieramy wyniki
    final results = await Future.wait(futures);
    for (var list in results) {
      allEvents.addAll(list);
    }

    // Usuwamy duplikaty
    final Map<String, SportEvent> unique = {};
    for (var e in allEvents) { unique[e.id] = e; }

    debugPrint('Sowa Sports V8.0: Zakończono. Łącznie unikalnych: ${unique.length}');
    return unique.values.toList();
  }

  /// Określa które ligi pobrać na podstawie wyboru użytkownika
  List<SportLeague> _getLeaguesToFetch(List<String>? selectedLeagueIds) {
    if (selectedLeagueIds == null || selectedLeagueIds.isEmpty) {
      // Domyślnie: wszystkie ligi z API
      return SportLeague.allLeagues.where((l) => l.hasApi).toList();
    }
    return selectedLeagueIds
        .map((id) => SportLeague.findById(id))
        .whereType<SportLeague>()
        .where((l) => l.hasApi)
        .toList();
  }

  /// ESPN Scoreboard — darmowe, bez klucza
  Future<List<SportEvent>> _fetchEspnScoreboard(String sport, String league, SportType type, String competition) async {
    try {
      final url = 'https://site.api.espn.com/apis/site/v2/sports/$sport/$league/scoreboard';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List events = data['events'] ?? [];
        final now = DateTime.now();

        return events.where((e) {
          // Filtruj preseason i mecze dalej niż 7 dni
          final eventState = e['status']?['type']?['state'] ?? '';
          if (eventState == 'pre') {
            // Sprawdź datę — jeśli dalej niż 7 dni, pomiń
            try {
              final eventDate = DateTime.parse(e['date'] ?? '').toLocal();
              if (eventDate.difference(now).inDays > 7) return false;
            } catch (_) {}
          }
          return true;
        }).map((e) {
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

          // Status
          final statusType = e['status']?['type']?['name'] ?? '';
          EventStatus status;
          switch (statusType) {
            case 'STATUS_FINAL':
            case 'STATUS_END_PERIOD':
            case 'STATUS_POSTPONED':
              status = EventStatus.finished;
              break;
            case 'STATUS_IN_PROGRESS':
            case 'STATUS_HALFTIME':
            case 'STATUS_TIMEOUT':
              status = EventStatus.live;
              break;
            default:
              status = EventStatus.scheduled;
          }

          // Data
          DateTime eventDate;
          try {
            eventDate = DateTime.parse(e['date'] ?? DateTime.now().toIso8601String()).toLocal();
          } catch (_) {
            eventDate = DateTime.now();
          }

          return MatchEvent(
            id: '${type.name}_${e['id']}',
            type: type,
            date: eventDate,
            status: status,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            score: "$homeScore - $awayScore",
            competition: competition,
            homeLogo: homeLogo,
            awayLogo: awayLogo,
          );
        }).toList();
      } else {
        debugPrint('Sowa Sports: ESPN $competition — HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Sowa Sports: Błąd ESPN $competition: $e');
    }
    return [];
  }

  /// TheSportsDB — eventsnextleague.php (nadchodzące mecze dla ligi)
  Future<List<SportEvent>> _fetchTsdbLeague(SportLeague league) async {
    try {
      final url = 'https://www.thesportsdb.com/api/v1/json/$_theSportsDbKey/eventsnextleague.php?id=${league.tsdbLeagueId}';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List allEvents = data['events'] ?? [];
        final List<SportEvent> events = [];

        for (var e in allEvents) {
          DateTime? matchDateTime;
          try {
            final datePart = e['dateEvent'];
            final timePart = e['strTime'] ?? '00:00:00';
            matchDateTime = DateTime.parse("${datePart}T$timePart");
          } catch (_) {
            try { matchDateTime = DateTime.parse(e['dateEvent']); } catch (_) { continue; }
          }
          events.add(MatchEvent(
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
        debugPrint('Sowa Sports: ${league.name} — ${events.length} meczy (next)');
        return events;
      }
    } catch (e) {
      debugPrint('Sowa Sports: Błąd TSDB ${league.name}: $e');
    }
    return [];
  }

  /// F1 — OpenF1 API
  Future<List<SportEvent>> _fetchF1() async {
    try {
      final response = await http.get(Uri.parse('https://api.openf1.org/v1/sessions')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List sessions = data is List ? data : [];
        final nowUtc = DateTime.now().toUtc();
        final nextRaces = sessions
            .where((s) => s['session_type'] == 'Race')
            .where((s) {
              try { return DateTime.parse(s['date_start']).isAfter(nowUtc); } catch (_) { return false; }
            })
            .toList()
          ..sort((a, b) => DateTime.parse(a['date_start']).compareTo(DateTime.parse(b['date_start'])));
        if (nextRaces.isNotEmpty) {
          final r = nextRaces[0];
          final meeting = r['meeting'] ?? {};
          return [RaceEvent(
            id: 'f1_${r['session_key']}',
            type: SportType.f1,
            date: DateTime.parse(r['date_start']),
            status: EventStatus.scheduled,
            raceName: r['session_name'] ?? meeting['meeting_name'] ?? 'F1 Race',
            circuitName: meeting['circuit_short_name'] ?? '',
            countryCode: meeting['country_code'] ?? '',
          )];
        }
      } else {
        debugPrint('Sowa Sports: F1 — HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Sowa Sports: Błąd F1: $e');
    }
    return [];
  }

  EventStatus _mapTsdbStatus(String? status) {
    if (status == 'FT') return EventStatus.finished;
    if (status == 'NS' || status == 'PST') return EventStatus.scheduled;
    return EventStatus.live;
  }
}
