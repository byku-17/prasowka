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

    // --- LOGIKA DATY (PODRÓŻ W CZASIE 2026 -> 2024) ---
    final now = DateTime.now();
    final DateTime referenceNow = now.year == 2026 
        ? DateTime(2024, now.month, now.day, now.hour, now.minute) 
        : now;
    
    debugPrint('Sowa Sports V8.8: Start (Reference: $referenceNow)');

    final leaguesToFetch = _getLeaguesToFetch(selectedLeagueIds);

    // Separacja źródeł (Koniec z blokadą else-if!)
    final espnLeagues = <SportLeague>[];
    final tsdbLeagues = <SportLeague>[];
    SportLeague? f1League;
    bool needsTennis = false;

    for (final league in leaguesToFetch) {
      if (league.id == 'f1') {
        f1League = league;
      } else if (league.id == 'tennis_wta' || league.id == 'tennis_atp') {
        needsTennis = true;
      } 
      
      // PRIORYTET: Piłka nożna idzie do TSDB, reszta do ESPN
      if (league.discipline == SportDiscipline.football && league.tsdbLeagueId != null) {
        tsdbLeagues.add(league);
      } else if (league.espnSport != null && league.espnLeague != null) {
        espnLeagues.add(league);
      }
    }

    final dateStr = referenceNow.toIso8601String().split('T')[0].replaceAll('-', '');

    // 1. ESPN
    final groupedEspn = <String, List<SportLeague>>{};
    for (final league in espnLeagues) {
      final key = '${league.espnSport}_${league.espnLeague}';
      groupedEspn.putIfAbsent(key, () => []).add(league);
    }
    for (final entry in groupedEspn.entries) {
      final l = entry.value.first;
      futures.add(_fetchEspnScoreboard(l.espnSport!, l.espnLeague!, l.sportType, l.name, dateStr, referenceNow));
    }

    // 2. TheSportsDB
    for (final league in tsdbLeagues) {
      futures.add(_fetchTsdbLeague(league, referenceNow));
    }

    // 3. F1 & Tenis
    if (f1League != null) futures.add(_fetchF1(referenceNow));
    if (needsTennis) futures.add(_fetchTennis(referenceNow));

    final results = await Future.wait(futures);
    for (var list in results) {
      allEvents.addAll(list);
    }

    final Map<String, SportEvent> unique = {};
    for (var e in allEvents) { unique[e.id] = e; }

    debugPrint('Sowa Sports V8.8: Zakończono. Unikalnych: ${unique.length}');
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

  Future<List<SportEvent>> _fetchEspnScoreboard(String sport, String league, SportType type, String competition, String dateStr, DateTime referenceNow) async {
    try {
      final url = 'https://site.api.espn.com/apis/site/v2/sports/$sport/$league/scoreboard?dates=$dateStr';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List events = data['events'] ?? [];
        final List<SportEvent> result = [];
        for (var e in events) {
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
          
          // Filtruj preseason (do 7 dni w przyszłości)
          if (statusType == 'STATUS_SCHEDULED' || statusType == 'STATUS_PRE') {
            try {
              final eventDate = DateTime.parse(e['date']);
              if (eventDate.isAfter(referenceNow.add(const Duration(days: 7)))) {
                continue;
              }
            } catch (_) {}
          }
          
          EventStatus status = statusType == 'STATUS_FINAL' ? EventStatus.finished : (statusType == 'STATUS_IN_PROGRESS' ? EventStatus.live : EventStatus.scheduled);

          result.add(MatchEvent(
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
          ));
        }
        return result;
      }
    } catch (_) {}
    return [];
  }

  Future<List<SportEvent>> _fetchTsdbLeague(SportLeague league, DateTime referenceNow) async {
    try {
      // Tylko eventsnextleague — eventslastleague zwraca śmieci
      final response = await http.get(Uri.parse('https://www.thesportsdb.com/api/v1/json/$_theSportsDbKey/eventsnextleague.php?id=${league.tsdbLeagueId}'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List events = data['events'] ?? [];
        final List<SportEvent> result = [];
        for (var e in events) {
          DateTime? matchDate;
          try { matchDate = DateTime.parse("${e['dateEvent']}T${e['strTime'] ?? '00:00:00'}"); }
          catch (_) { try { matchDate = DateTime.parse(e['dateEvent']); } catch (_) { continue; } }

          if (matchDate.difference(referenceNow).inDays.abs() <= 5) {
            result.add(MatchEvent(
              id: 'tsdb_${league.id}_${e['idEvent']}',
              type: league.sportType,
              date: matchDate.toLocal(),
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
        return result;
      }
    } catch (_) {}
    return [];
  }

  Future<List<SportEvent>> _fetchF1(DateTime referenceNow) async {
    try {
      final response = await http.get(Uri.parse('https://api.openf1.org/v1/sessions?year=${referenceNow.year}')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List sessions = data is List ? data : [];
        final races = sessions.where((s) => s['session_type'] == 'Race').toList()..sort((a, b) => DateTime.parse(a['date_start']).compareTo(DateTime.parse(b['date_start'])));
        final nextRace = races.firstWhere((s) => DateTime.parse(s['date_start']).isAfter(referenceNow.toUtc()), orElse: () => races.last);
        final meeting = nextRace['meeting'] ?? {};
        return [RaceEvent(id: 'f1_${nextRace['session_key']}', type: SportType.f1, date: DateTime.parse(nextRace['date_start']).toLocal(), status: EventStatus.scheduled, raceName: nextRace['session_name'] ?? meeting['meeting_name'] ?? 'F1 Race', circuitName: meeting['circuit_short_name'] ?? '', countryCode: meeting['country_code'] ?? '')];
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
        final List<SportEvent> result = [];
        for (var e in events) {
          DateTime? matchDate;
          try { matchDate = DateTime.parse("${e['dateEvent']}T${e['strTime'] ?? '00:00:00'}"); }
          catch (_) { try { matchDate = DateTime.parse(e['dateEvent']); } catch (_) { continue; } }
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
        }
        return result;
      }
    } catch (_) {}
    return [];
  }

  EventStatus _mapTsdbStatus(String? status) => status == 'FT' ? EventStatus.finished : (status == 'NS' || status == 'PST' ? EventStatus.scheduled : EventStatus.live);
}
