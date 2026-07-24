import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:prasowka/models/sport_event.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SportsService {
  String get _footballApiKey => dotenv.env['FOOTBALL_API_KEY'] ?? '';
  String get _nbaApiKey => dotenv.env['NBA_API_KEY'] ?? '';
  String get _rapidApiKey => dotenv.env['RAPID_API_KEY'] ?? '';
  String get _theSportsDbKey => dotenv.env['THESPORTSDB_API_KEY'] ?? '1';

  bool _isMissing(String key) => key.isEmpty || key == 'YOUR_KEY_HERE' || key.length < 5;

  Future<List<SportEvent>> fetchAllEvents({
    List<String>? enabledSports,
    List<String>? enabledLeagues,
  }) async {
    final List<SportEvent> allEvents = [];
    final List<Future<List<SportEvent>>> futures = [];

    // Definiujemy daty: Wczoraj i Dziś (Jutro pomijamy dla oszczędności limitu)
    final now = DateTime.now();
    final List<String> dates = [
      now.subtract(const Duration(days: 1)).toIso8601String().split('T')[0],
      now.toIso8601String().split('T')[0],
    ];

    debugPrint('Sowa Sports V3: Start (Optymalizacja Smart-Fetch dla $dates)');

    // 1. PIŁKA NOŻNA (RapidAPI - Jeden strzał na dzień zamiast pętli po ligach!)
    if (enabledSports == null || enabledSports.contains('football') || enabledSports.contains('ekstraklasa')) {
      if (!_isMissing(_rapidApiKey)) {
        futures.add(_fetchSoccerUniversal(dates: dates, enabledLeagues: enabledLeagues));
      }
    }

    // 2. NBA
    if (enabledSports == null || enabledSports.contains('nba')) {
      if (!_isMissing(_nbaApiKey)) {
        futures.add(_fetchNBA(dates: dates));
      } else {
        allEvents.addAll(_getNBAMocks());
      }
    }

    // 3. INNE PRZEZ RAPIDAPI (Również zoptymalizowane do jednego strzału na dzień)
    if (!_isMissing(_rapidApiKey)) {
      if (enabledSports?.contains('nhl') ?? false) futures.add(_fetchRapidUniversal('hockey', SportType.nhl, dates: dates));
      if (enabledSports?.contains('mlb') ?? false) futures.add(_fetchRapidUniversal('baseball', SportType.mlb, dates: dates));
      if (enabledSports?.contains('nfl') ?? false) futures.add(_fetchRapidUniversal('american-football', SportType.nfl, dates: dates));
      if (enabledSports?.contains('volleyball') ?? false) futures.add(_fetchRapidUniversal('volleyball', SportType.volleyball, dates: [dates.last]));
      if (enabledSports?.contains('handball') ?? false) futures.add(_fetchRapidUniversal('handball', SportType.handball, dates: [dates.last]));
    }

    // 4. F1 & TENNIS (Zawsze, darmowe lub proste API)
    if (enabledSports == null || enabledSports.contains('f1')) futures.add(_fetchF1());
    if (enabledSports == null || enabledSports.contains('tennis')) futures.add(_fetchTennis());

    try {
      final results = await Future.wait(futures);
      for (var list in results) {
        allEvents.addAll(list);
      }
    } catch (e) {
      debugPrint('Sowa Sports: Błąd krytyczny V3: $e');
    }

    if (allEvents.isEmpty && _isMissing(_rapidApiKey)) {
      return _getFootballMocks() + _getNBAMocks();
    }

    final Map<String, SportEvent> unique = {};
    for (var e in allEvents) { unique[e.id] = e; }
    
    debugPrint('Sowa Sports: Zakończono V3. Łącznie unikalnych zdarzeń: ${unique.length}');
    return unique.values.toList();
  }

  /// POBIERA WSZYSTKIE MECZE Z DNIA (Zamiast pętli po ligach - OSZCZĘDNOŚĆ LIMITU!)
  Future<List<SportEvent>> _fetchSoccerUniversal({required List<String> dates, List<String>? enabledLeagues}) async {
    final List<SportEvent> results = [];
    
    final Map<String, int> leagueMap = {
      'EKSTRAKLASA': 106,
      'PL': 39,
      'PD': 140,
      'BL1': 78,
      'SA': 135,
      'FL1': 61,
      'CL': 2,
    };

    final activeLeagueIds = (enabledLeagues ?? leagueMap.keys.toList())
        .map((code) => leagueMap[code])
        .where((id) => id != null)
        .cast<int>()
        .toList();

    for (var date in dates) {
      try {
        // Wykorzystujemy fakt, że API-Football pozwala na pobieranie meczów po dacie
        final url = 'https://api-football-v1.p.rapidapi.com/v3/fixtures?date=$date';
        debugPrint('Sowa Sports: Smart-Fetch Soccer ($date) -> 1 zapytanie zamiast ${activeLeagueIds.length}');

        final response = await http.get(
          Uri.parse(url),
          headers: {
            'x-rapidapi-key': _rapidApiKey,
            'x-rapidapi-host': 'api-football-v1.p.rapidapi.com'
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List matches = data['response'] ?? [];
          
          // Filtrujemy mecze w pamięci telefonu (to nic nie kosztuje!)
          final filtered = matches.where((m) => activeLeagueIds.contains(m['league']?['id']));
          debugPrint('Sowa Sports: Soccer ($date) - Serwer zwrócił ${matches.length} meczów, wybrano $activeLeagueIds: ${filtered.length} meczów');

          results.addAll(filtered.map((m) {
            final f = m['fixture'];
            return MatchEvent(
              id: 'rapid_fb_${f['id']}',
              type: SportType.football,
              date: DateTime.parse(f['date']).toLocal(),
              status: _mapRapidStatus(f['status']['short']),
              homeTeam: m['teams']['home']['name'],
              awayTeam: m['teams']['away']['name'],
              score: "${m['goals']['home'] ?? 0} - ${m['goals']['away'] ?? 0}",
              competition: m['league']['name'],
              homeLogo: m['teams']['home']['logo'],
              awayLogo: m['teams']['away']['logo'],
              time: f['status']['elapsed']?.toString(),
            );
          }));
        } else {
           debugPrint('Sowa Sports: Soccer Error ${response.statusCode} na $date: ${response.body}');
        }
      } catch (e) {
        debugPrint('Sowa Sports: Soccer Exception na $date: $e');
      }
    }
    return results;
  }

  Future<List<SportEvent>> _fetchNBA({required List<String> dates}) async {
    final List<SportEvent> results = [];
    for (var date in dates) {
      try {
        final url = 'https://api.balldontlie.io/v1/games?dates[]=$date';
        debugPrint('Sowa Sports: NBA ($date) -> $url');

        final response = await http.get(Uri.parse(url), headers: {'Authorization': _nbaApiKey});
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List games = data['data'] ?? [];
          debugPrint('Sowa Sports: NBA ($date) OK: ${games.length} meczów');
          results.addAll(games.map((g) => MatchEvent(
            id: 'nba_${g['id']}',
            type: SportType.nba,
            date: DateTime.parse(g['date']).toLocal(),
            status: g['status'].toString().contains(':') ? EventStatus.scheduled : (g['status'] == 'Final' ? EventStatus.finished : EventStatus.live),
            homeTeam: g['home_team']['full_name'],
            awayTeam: g['visitor_team']['full_name'],
            score: "${g['home_team_score']} - ${g['visitor_team_score']}",
            competition: 'NBA',
          )));
        }
      } catch (_) {}
    }
    return results;
  }

  Future<List<SportEvent>> _fetchRapidUniversal(String endpoint, SportType type, {required List<String> dates}) async {
    final List<SportEvent> results = [];
    final host = '$endpoint-api-v1.p.rapidapi.com';

    for (var date in dates) {
      try {
        final url = 'https://$host/games?date=$date';
        debugPrint('Sowa Sports: Smart-Fetch $endpoint ($date)');
        final response = await http.get(Uri.parse(url), headers: {
          'x-rapidapi-key': _rapidApiKey,
          'x-rapidapi-host': host
        });

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List res = data['response'] ?? [];
          results.addAll(res.map((item) {
            final game = item['game'] ?? item;
            final teams = item['teams'];
            final scores = item['scores'];
            return MatchEvent(
              id: '${type.name}_${game['id']}',
              type: type,
              date: DateTime.parse(game['date'] ?? game['utcDate']).toLocal(),
              status: _mapRapidStatus(item['status']?['short'] ?? 'NS'),
              homeTeam: teams['home']['name'],
              awayTeam: teams['away']['name'],
              score: type == SportType.mlb ? "${item['scores']['home']['total'] ?? 0} - ${item['scores']['away']['total'] ?? 0}" : "${item['scores']['home'] ?? 0} - ${item['scores']['away'] ?? 0}",
              competition: item['league']?['name'] ?? type.name.toUpperCase(),
              homeLogo: item['teams']['home']['logo'],
              awayLogo: item['teams']['away']['logo'],
            );
          }));
        }
      } catch (_) {}
    }
    return results;
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

  Future<List<SportEvent>> _fetchTennis() async {
    try {
      final url = 'https://www.thesportsdb.com/api/v1/json/$_theSportsDbKey/eventsday.php?d=${DateTime.now().toIso8601String().split('T')[0]}&s=Tennis';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List events = data['events'] ?? [];
        return events.map((e) => MatchEvent(id: 'tennis_${e['idEvent']}', type: SportType.tennis, date: DateTime.parse("${e['dateEvent']}T${e['strTime']}"), status: e['strStatus'] == 'FT' ? EventStatus.finished : EventStatus.scheduled, homeTeam: e['strHomeTeam'], awayTeam: e['strAwayTeam'], score: e['intHomeScore'] != null ? "${e['intHomeScore']} - ${e['intAwayScore']}" : "v", competition: e['strLeague'], homeLogo: e['strHomeTeamBadge'], awayLogo: e['strAwayTeamBadge'])).toList();
      }
    } catch (_) {}
    return [];
  }

  EventStatus _mapRapidStatus(String short) {
    if (short == 'NS' || short == 'TBD' || short == 'Scheduled') return EventStatus.scheduled;
    if (short == 'FT' || short == 'AET' || short == 'PEN' || short == 'Finished') return EventStatus.finished;
    return EventStatus.live;
  }

  List<SportEvent> _getFootballMocks() => [
    MatchEvent(id: 'fb_mock_1', type: SportType.football, date: DateTime.now(), status: EventStatus.live, homeTeam: 'Real Madryt', awayTeam: 'FC Barcelona', score: '2 - 1', time: '72\'', competition: 'La Liga (MOCK)', homeLogo: 'https://crests.football-data.org/86.png', awayLogo: 'https://crests.football-data.org/81.png')
  ];

  List<SportEvent> _getNBAMocks() => [
    MatchEvent(id: 'nba_mock_1', type: SportType.nba, date: DateTime.now().subtract(const Duration(hours: 5)), status: EventStatus.finished, homeTeam: 'Lakers', awayTeam: 'Warriors', score: '112 - 105', competition: 'NBA (MOCK)')
  ];
}
