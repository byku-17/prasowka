import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prasowka/models/sport_event.dart';
import 'package:prasowka/models/sport_league.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SportsService {
  String get _theSportsDbKey => dotenv.env['THESPORTSDB_API_KEY'] ?? '3';

  Future<List<SportEvent>> fetchAllEvents({List<String>? selectedLeagueIds}) async {
    final List<SportEvent> allEvents = [];
    final List<Future<List<SportEvent>>> futures = [];

    final now = DateTime.now();
    debugPrint('Sowa Sports V8.6: Start ($now, Selected: ${selectedLeagueIds?.length ?? "all"})');

    final leaguesToFetch = _getLeaguesToFetch(selectedLeagueIds);

    final espnLeagues = <SportLeague>[];
    final tsdbLeagues = <SportLeague>[];
    SportLeague? f1League;
    bool needsTennis = false;

    for (final league in leaguesToFetch) {
      if (league.id == 'f1') {
        f1League = league;
      } else if (league.id == 'tennis_wta' || league.id == 'tennis_atp') {
        needsTennis = true;
      } else if (league.espnSport != null && league.espnLeague != null) {
        espnLeagues.add(league);
      } else if (league.tsdbLeagueId != null) {
        tsdbLeagues.add(league);
      }
    }

    // ESPN — jeden request per liga, z datą ddmmYYYY dla ESPN
    final dateStr = '${now.day.toString().padLeft(2, '0')}${now.month.toString().padLeft(2, '0')}${now.year}';

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

    // TheSportsDB — 1 zapytanie per liga (eventsnextleague)
    for (final league in tsdbLeagues) {
      futures.add(_fetchTsdbLeague(league));
    }

    // F1 — bez ?year=, pobieramy wszystkie sesje i filtrujemy
    if (f1League != null) {
      futures.add(_fetchF1());
    }

    // Tenis — tylko gdy wybrany
    if (needsTennis) {
      futures.add(_fetchTennis(now));
    }

    final results = await Future.wait(futures);
    for (var list in results) {
      allEvents.addAll(list);
    }

    final Map<String, SportEvent> unique = {};
    for (var e in allEvents) { unique[e.id] = e; }

    debugPrint('Sowa Sports V8.6: Zakończono. Unikalnych: ${unique.length}');
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

  /// ESPN — z filtrem preseason (>7 dni w przyszłość = pomijamy)
  Future<List<SportEvent>> _fetchEspnScoreboard(String sport, String league, SportType type, String competition, String dateStr) async {
    try {
      final url = 'https://site.api.espn.com/apis/site/v2/sports/$sport/$league/scoreboard?dates=$dateStr';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List events = data['events'] ?? [];
        final now = DateTime.now();

        return events.where((e) {
          // Filtruj preseason + mecze >7 dni w przyszłość
          final eventState = e['status']?['type']?['state'] ?? '';
          if (eventState == 'pre') {
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
      }
    } catch (_) {}
    return [];
  }

  /// TheSportsDB — 1 zapytanie per liga (eventsnextleague)
  Future<List<SportEvent>> _fetchTsdbLeague(SportLeague league) async {
    try {
      final url = 'https://www.thesportsdb.com/api/v1/json/$_theSportsDbKey/eventsnextleague.php?id=${league.tsdbLeagueId}';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List events = data['events'] ?? [];
        final List<SportEvent> result = [];

        for (var e in events) {
          DateTime? matchDateTime;
          try {
            final datePart = e['dateEvent'];
            final timePart = e['strTime'] ?? '00:00:00';
            matchDateTime = DateTime.parse("${datePart}T$timePart");
          } catch (_) {
            try { matchDateTime = DateTime.parse(e['dateEvent']); } catch (_) { continue; }
          }

          result.add(MatchEvent(
            id: 'tsdb_${league.id}_${e['idEvent']}',
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
        debugPrint('Sowa Sports: ${league.name} — ${result.length} meczy');
        return result;
      }
    } catch (_) {}
    return [];
  }

  /// F1 — bez ?year=, pobiera wszystkie sesje i filtruje przyszłe
  Future<List<SportEvent>> _fetchF1() async {
    try {
      final response = await http.get(Uri.parse('https://api.openf1.org/v1/sessions')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List sessions = data is List ? data : [];
        final nowUtc = DateTime.now().toUtc();

        final races = sessions
            .where((s) => s['session_type'] == 'Race')
            .where((s) {
              try { return DateTime.parse(s['date_start']).isAfter(nowUtc); } catch (_) { return false; }
            })
            .toList()
          ..sort((a, b) => DateTime.parse(a['date_start']).compareTo(DateTime.parse(b['date_start'])));

        if (races.isNotEmpty) {
          final r = races[0];
          final meeting = r['meeting'] ?? {};
          return [RaceEvent(
            id: 'f1_${r['session_key']}',
            type: SportType.f1,
            date: DateTime.parse(r['date_start']).toLocal(),
            status: EventStatus.scheduled,
            raceName: r['session_name'] ?? meeting['meeting_name'] ?? 'F1 Race',
            circuitName: meeting['circuit_short_name'] ?? '',
            countryCode: meeting['country_code'] ?? '',
          )];
        }
      }
    } catch (_) {}
    return [];
  }

  /// Tenis — TheSportsDB eventsday.php (tylko gdy user wybrał)
  Future<List<SportEvent>> _fetchTennis(DateTime now) async {
    try {
      final dateStr = now.toIso8601String().split('T')[0];
      final url = 'https://www.thesportsdb.com/api/v1/json/$_theSportsDbKey/eventsday.php?d=$dateStr&s=Tennis';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List events = data['events'] ?? [];
        final List<SportEvent> result = [];
        for (var e in events) {
          try {
            final matchDate = DateTime.parse("${e['dateEvent']}T${e['strTime'] ?? '00:00:00'}");
            result.add(MatchEvent(
              id: 'tennis_${e['idEvent']}',
              type: SportType.tennis,
              date: matchDate.toLocal(),
              status: e['strStatus'] == 'FT' ? EventStatus.finished : EventStatus.scheduled,
              homeTeam: e['strHomeTeam'] ?? '?',
              awayTeam: e['strAwayTeam'] ?? '?',
              score: e['intHomeScore'] != null ? "${e['intHomeScore']} - ${e['intAwayScore']}" : "v",
              competition: e['strLeague'] ?? 'Tennis',
              homeLogo: e['strHomeTeamBadge'],
              awayLogo: e['strAwayTeamBadge'],
            ));
          } catch (_) {}
        }
        return result;
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
