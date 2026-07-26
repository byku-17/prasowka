import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prasowka/models/sport_event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SportsService {
  String get _nbaApiKey => dotenv.env['NBA_API_KEY'] ?? '';
  String get _rapidApiKey => dotenv.env['RAPID_API_KEY'] ?? '';
  String get _theSportsDbKey => dotenv.env['THESPORTSDB_API_KEY'] ?? '3';

  bool _isMissing(String key) => key.isEmpty || key == 'YOUR_KEY_HERE';

  Future<List<SportEvent>> fetchAllEvents() async {
    final List<SportEvent> allEvents = [];
    final List<Future<List<SportEvent>>> futures = [];

    final now = DateTime.now();
    debugPrint('Sowa Sports V6.0: Start (Real: $now)');

    // 1. PIŁKA NOŻNA (TheSportsDB — eventsday.php, free tier z kluczem '3')
    futures.add(_fetchFootballDays(now));

    // 2. NBA (balldontlie)
    if (!_isMissing(_nbaApiKey)) {
      final dateStr = now.toIso8601String().split('T')[0];
      futures.add(_fetchNBA(dateStr));
    }

    // 3. INNE (RapidAPI - NHL, MLB)
    if (!_isMissing(_rapidApiKey)) {
      final dateStr = now.toIso8601String().split('T')[0];
      futures.add(_fetchRapidGeneric('hockey', SportType.nhl, dateStr));
      futures.add(_fetchRapidGeneric('baseball', SportType.mlb, dateStr));
    }

    // 4. F1 & TENNIS (Zawsze dostępne)
    futures.add(_fetchF1());
    futures.add(_fetchTennis(now));

    // Zbieramy wyniki jeden po drugim — jeśli jeden API zawiedzie, reszta działa dalej
    final results = await Future.wait(futures);
    for (var list in results) {
      allEvents.addAll(list);
    }

    // Usuwamy duplikaty
    final Map<String, SportEvent> unique = {};
    for (var e in allEvents) { unique[e.id] = e; }
    
    debugPrint('Sowa Sports V6.0: Zakończono. Łącznie unikalnych: ${unique.length}');
    return unique.values.toList();
  }

  /// POBIERA MECZE PIŁKI NOŻNEJ — eventsday.php (DZIŚ + JUTRO + Wczoraj)
  final Set<String> _soccerLeagueIds = {'4422', '4328', '4335', '4331', '4332', '4334'};

  Future<List<SportEvent>> _fetchFootballDays(DateTime now) async {
    final List<SportEvent> events = [];
    final List<Future<void>> futures = [];

    for (int offset in [-1, 0, 1]) {
      final date = now.add(Duration(days: offset));
      final dateStr = date.toIso8601String().split('T')[0];
      futures.add(() async {
        try {
          final url = 'https://www.thesportsdb.com/api/v1/json/$_theSportsDbKey/eventsday.php?d=$dateStr';
          final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final List allEvents = data['events'] ?? [];
            for (var e in allEvents) {
              final leagueId = e['idLeague']?.toString();
              if (leagueId == null || !_soccerLeagueIds.contains(leagueId)) continue;
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
                type: SportType.football,
                date: matchDateTime.toLocal(),
                status: _mapTsdbStatus(e['strStatus']),
                homeTeam: e['strHomeTeam'] ?? '?',
                awayTeam: e['strAwayTeam'] ?? '?',
                score: e['intHomeScore'] != null ? "${e['intHomeScore']} - ${e['intAwayScore']}" : "v",
                competition: e['strLeague'] ?? 'Piłka Nożna',
                homeLogo: e['strHomeTeamBadge'],
                awayLogo: e['strAwayTeamBadge'],
              ));
            }
          } else {
            debugPrint('Sowa Sports: TheSportsDB eventsday $dateStr — HTTP ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('Sowa Sports: Błąd eventsday $dateStr: $e');
        }
      }());
    }

    await Future.wait(futures);
    debugPrint('Sowa Sports: Piłka nożna — ${events.length} meczy (dziś±1)');
    return events;
  }

  Future<List<SportEvent>> _fetchNBA(String date) async {
    try {
      final url = 'https://api.balldontlie.io/v1/games?dates[]=$date';
      final response = await http.get(Uri.parse(url), headers: {'Authorization': _nbaApiKey});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List games = data['data'] ?? [];
        return games.map((g) => MatchEvent(
          id: 'nba_${g['id']}',
          type: SportType.nba,
          date: DateTime.parse(g['date']).toLocal(),
          status: g['status'].toString().contains(':') ? EventStatus.scheduled : (g['status'] == 'Final' ? EventStatus.finished : EventStatus.live),
          homeTeam: g['home_team']['full_name'],
          awayTeam: g['visitor_team']['full_name'],
          score: "${g['home_team_score']} - ${g['visitor_team_score']}",
          competition: 'NBA',
        )).toList();
      } else {
        debugPrint('Sowa Sports: NBA — HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Sowa Sports: Błąd NBA: $e');
    }
    return [];
  }

  Future<List<SportEvent>> _fetchRapidGeneric(String endpoint, SportType type, String date) async {
    try {
      final host = '$endpoint-api-v1.p.rapidapi.com';
      final url = 'https://$host/games?date=$date';
      final response = await http.get(Uri.parse(url), headers: {
        'x-rapidapi-key': _rapidApiKey,
        'x-rapidapi-host': host
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List res = data['response'] ?? [];
        return res.map((item) {
          final game = item['game'] ?? item;
          final teams = item['teams'];
          return MatchEvent(
            id: '${type.name}_${game['id']}',
            type: type,
            date: DateTime.parse(game['date'] ?? game['utcDate'] ?? game['start'] ?? DateTime.now().toIso8601String()).toLocal(),
            status: _mapRapidStatus(item['status']?['short'] ?? 'NS'),
            homeTeam: teams['home']['name'],
            awayTeam: teams['away']['name'],
            score: type == SportType.mlb ? "${item['scores']?['home']?['total'] ?? 0} - ${item['scores']?['away']?['total'] ?? 0}" : "${item['scores']?['home'] ?? 0} - ${item['scores']?['away'] ?? 0}",
            competition: item['league']?['name'] ?? type.name.toUpperCase(),
            homeLogo: teams['home']['logo'],
            awayLogo: teams['away']['logo'],
          );
        }).toList();
      } else {
        debugPrint('Sowa Sports: RapidAPI $endpoint — HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Sowa Sports: Błąd RapidAPI $endpoint: $e');
    }
    return [];
  }

  Future<List<SportEvent>> _fetchF1() async {
    try {
      final year = DateTime.now().year;
      final response = await http.get(Uri.parse('https://api.openf1.org/v1/sessions?year=$year')).timeout(const Duration(seconds: 10));
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

  Future<List<SportEvent>> _fetchTennis(DateTime now) async {
    try {
      final dateStr = now.toIso8601String().split('T')[0];
      final url = 'https://www.thesportsdb.com/api/v1/json/$_theSportsDbKey/eventsday.php?d=$dateStr&s=Tennis';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List events = data['events'] ?? [];
        return events.map((e) => MatchEvent(id: 'tennis_${e['idEvent']}', type: SportType.tennis, date: DateTime.parse("${e['dateEvent']}T${e['strTime']}"), status: e['strStatus'] == 'FT' ? EventStatus.finished : EventStatus.scheduled, homeTeam: e['strHomeTeam'], awayTeam: e['strAwayTeam'], score: e['intHomeScore'] != null ? "${e['intHomeScore']} - ${e['intAwayScore']}" : "v", competition: e['strLeague'], homeLogo: e['strHomeTeamBadge'], awayLogo: e['strAwayTeamBadge'])).toList();
      } else {
        debugPrint('Sowa Sports: Tenis — HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Sowa Sports: Błąd tenisa: $e');
    }
    return [];
  }

  EventStatus _mapTsdbStatus(String? status) {
    if (status == 'FT') return EventStatus.finished;
    if (status == 'NS' || status == 'PST') return EventStatus.scheduled;
    return EventStatus.live;
  }

  EventStatus _mapRapidStatus(String short) {
    if (short == 'NS' || short == 'TBD' || short == 'Scheduled' || short == 'PST') return EventStatus.scheduled;
    if (short == 'FT' || short == 'AET' || short == 'PEN' || short == 'Finished') return EventStatus.finished;
    return EventStatus.live;
  }
}
