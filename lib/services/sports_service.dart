import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prasowka/models/sport_event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SportsService {
  String get _nbaApiKey => dotenv.env['NBA_API_KEY'] ?? '';
  String get _rapidApiKey => dotenv.env['RAPID_API_KEY'] ?? '';
  String get _theSportsDbKey => dotenv.env['THESPORTSDB_API_KEY'] ?? '1';

  bool _isMissing(String key) => key.isEmpty || key == 'YOUR_KEY_HERE';

  Future<List<SportEvent>> fetchAllEvents() async {
    final List<SportEvent> allEvents = [];
    final List<Future<List<SportEvent>>> futures = [];

    // --- LOGIKA DATY (PODRÓŻ W CZASIE 2026 -> 2024) ---
    final now = DateTime.now();
    final DateTime referenceNow = now.year == 2026 
        ? DateTime(2024, now.month, now.day, now.hour, now.minute) 
        : now;
    
    debugPrint('Sowa Sports V4.2: Start (Reference: $referenceNow)');

    // 1. PIŁKA NOŻNA (TheSportsDB - Metoda Ligowa z Szerokim Radarem)
    // ID 4422: Ekstraklasa, 4328: PL, 4335: LaLiga, 4331: Bundesliga, 4332: SerieA, 4334: Ligue1
    final soccerLeagues = ['4422', '4328', '4335', '4331', '4332', '4334'];
    for (var id in soccerLeagues) {
      futures.add(_fetchLeagueEvents(id, referenceNow));
    }

    // 2. NBA (balldontlie)
    if (!_isMissing(_nbaApiKey)) {
      final dateStr = referenceNow.toIso8601String().split('T')[0];
      futures.add(_fetchNBA(dateStr));
    }

    // 3. INNE (RapidAPI - NHL, MLB)
    if (!_isMissing(_rapidApiKey)) {
      final dateStr = referenceNow.toIso8601String().split('T')[0];
      futures.add(_fetchRapidGeneric('hockey', SportType.nhl, dateStr));
      futures.add(_fetchRapidGeneric('baseball', SportType.mlb, dateStr));
    }

    // 4. F1 & TENNIS (Zawsze dostępne)
    futures.add(_fetchF1());
    futures.add(_fetchTennis(referenceNow));

    try {
      final results = await Future.wait(futures);
      for (var list in results) {
        allEvents.addAll(list);
      }
    } catch (e) {
      debugPrint('Sowa Sports: Błąd krytyczny V4.2: $e');
    }

    // Usuwamy duplikaty
    final Map<String, SportEvent> unique = {};
    for (var e in allEvents) { unique[e.id] = e; }
    
    debugPrint('Sowa Sports V4.2: Zakończono. Łącznie unikalnych: ${unique.length}');
    return unique.values.toList();
  }

  /// POBIERA WSZYSTKIE MECZE LIGI (+/- 7 DNI RADARU)
  Future<List<SportEvent>> _fetchLeagueEvents(String leagueId, DateTime referenceNow) async {
    try {
      final url = 'https://www.thesportsdb.com/api/v1/json/$_theSportsDbKey/eventsleague.php?id=$leagueId';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List events = data['events'] ?? [];
        
        // Radar 14-dniowy (+/- 7 dni), aby na pewno złapać mecze przy przesunięciu lat
        final filtered = events.where((e) {
          try {
             final matchDate = DateTime.parse(e['dateEvent']);
             final diff = matchDate.difference(referenceNow).inDays.abs();
             return diff <= 7;
          } catch (_) { return false; }
        });

        return filtered.map((e) {
          DateTime? matchDateTime;
          try {
            // Pancerne parowanie daty i czasu
            final datePart = e['dateEvent'];
            final timePart = e['strTime'] ?? '00:00:00';
            matchDateTime = DateTime.parse("${datePart}T$timePart");
          } catch (_) {
            matchDateTime = DateTime.parse(e['dateEvent']);
          }

          return MatchEvent(
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
          );
        }).toList();
      }
    } catch (_) {}
    return [];
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
      }
    } catch (_) {}
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
      }
    } catch (_) {}
    return [];
  }

  Future<List<SportEvent>> _fetchF1() async {
    try {
      final response = await http.get(Uri.parse('https://api.jolpica.org/ergast/f1/current/next.json'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final races = data['MRData']['RaceTable']['Races'];
        if (races.isEmpty) return [];
        final r = races[0];
        return [RaceEvent(id: 'f1_${r['round']}', type: SportType.f1, date: DateTime.parse("${r['date']}T${r['time']}"), status: EventStatus.scheduled, raceName: r['raceName'], circuitName: r['Circuit']['circuitName'], countryCode: r['Circuit']['Location']['country'])];
      }
    } catch (_) {}
    return [];
  }

  Future<List<SportEvent>> _fetchTennis(DateTime referenceNow) async {
    try {
      final dateStr = referenceNow.toIso8601String().split('T')[0];
      final url = 'https://www.thesportsdb.com/api/v1/json/$_theSportsDbKey/eventsday.php?d=$dateStr&s=Tennis';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List events = data['events'] ?? [];
        return events.map((e) => MatchEvent(id: 'tennis_${e['idEvent']}', type: SportType.tennis, date: DateTime.parse("${e['dateEvent']}T${e['strTime']}"), status: e['strStatus'] == 'FT' ? EventStatus.finished : EventStatus.scheduled, homeTeam: e['strHomeTeam'], awayTeam: e['strAwayTeam'], score: e['intHomeScore'] != null ? "${e['intHomeScore']} - ${e['intAwayScore']}" : "v", competition: e['strLeague'], homeLogo: e['strHomeTeamBadge'], awayLogo: e['strAwayTeamBadge'])).toList();
      }
    } catch (_) {}
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
