import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:prasowka/models/sport_event.dart';
import 'package:prasowka/services/sports_service.dart';
import 'package:prasowka/utils/text_utils.dart';

const String _pinnedBoxName = 'pinned_matches';

class SportsProvider with ChangeNotifier {
  final SportsService _service = SportsService();
  
  List<SportEvent> _events = [];
  final List<String> _debugLogs = [];
  bool _isLoading = false;
  DateTime? _lastFetch;
  Timer? _refreshTimer;
  List<String>? _currentFavorites;
  bool _currentOnlyFavorites = true;
  List<String>? _currentSelectedLeagues;

  List<SportEvent> get events => _events;
  List<String> get debugLogs => _debugLogs;
  bool get isLoading => _isLoading;
  DateTime? get lastFetch => _lastFetch;

  /// Zbiór ID przypiętych meczów
  Set<String> get pinnedMatchIds {
    if (!Hive.isBoxOpen(_pinnedBoxName)) return {};
    return Set<String>.from(Hive.box(_pinnedBoxName).keys.map((k) => k.toString()));
  }

  bool isMatchPinned(String matchId) => pinnedMatchIds.contains(matchId);

  Future<void> togglePinMatch(String matchId) async {
    if (!Hive.isBoxOpen(_pinnedBoxName)) {
      await Hive.openBox(_pinnedBoxName);
    }
    final box = Hive.box(_pinnedBoxName);
    if (box.containsKey(matchId)) {
      await box.delete(matchId);
    } else {
      await box.put(matchId, true);
    }
    notifyListeners();
  }

  Future<void> fetchEvents({
    List<String>? favoriteKeywords,
    bool onlyFavoriteTeams = true,
    List<String>? selectedLeagueIds,
    bool force = false
  }) {
    final hasLive = _events.any((e) => e.status == EventStatus.live);
    final hasFavorites = onlyFavoriteTeams && favoriteKeywords != null && favoriteKeywords.isNotEmpty;
    // LIVE: 1 min, z ulubionymi: 30 min (oszczędność API — fixtures z 4 krajów), bez: 15 min
    final ttl = hasLive ? 1 : (hasFavorites ? 30 : 15);

    if (!force && _lastFetch != null && DateTime.now().difference(_lastFetch!).inMinutes < ttl) {
      return Future.value();
    }

    _isLoading = true;
    _debugLogs.clear();
    _debugLogs.add('--- DIAGNOSTYKA V9.0 ---');
    _debugLogs.add('Start: ${DateTime.now().toString().split('.')[0]} (TTL: ${ttl}min)');
    notifyListeners();

    return _performFetch(favoriteKeywords, onlyFavoriteTeams, selectedLeagueIds);
  }

  Future<void> _performFetch(List<String>? favoriteKeywords, bool onlyFavoriteTeams, List<String>? selectedLeagueIds) async {
    try {
      final newEvents = await _service.fetchAllEvents(selectedLeagueIds: selectedLeagueIds);

      // 1. Filtrujemy pod zainteresowania
      List<SportEvent> filtered;
      if (favoriteKeywords != null && favoriteKeywords.isNotEmpty) {
        // Gdy user ma ulubione drużyny — pokaż tylko ich mecze
        filtered = _filterAndSortEvents(newEvents, favoriteKeywords, true);
        _debugLogs.add('Ulubione: ${favoriteKeywords.join(", ")}');
        _debugLogs.add('Po filtrze: ${filtered.length} z ${newEvents.length} meczów');
      } else if (onlyFavoriteTeams) {
        // Tryb "tylko ulubione" ale brak ulubionych → top ligi
        filtered = _filterTopLeagues(newEvents);
        _debugLogs.add('Top ligi: ${filtered.length} z ${newEvents.length}');
      } else {
        // Tryb "pokaż wszystko"
        filtered = newEvents;
        _debugLogs.add('Wszystko: ${filtered.length} meczów');
      }

      // 2. DISCOVERY MODE: Jeśli pusto, pokaż top 5 meczów z popularnych lig
      if (filtered.isEmpty && newEvents.isNotEmpty) {
        final topMatches = _filterTopLeagues(newEvents).take(5).toList();
        if (topMatches.isNotEmpty) {
          _debugLogs.add('Discovery Mode: Pokazuję top ${topMatches.length} meczów.');
          filtered = topMatches;
        } else {
          _debugLogs.add('Discovery Mode: Pokazuję wszystkie mecze z API.');
          filtered = newEvents.take(10).toList();
        }
      }

      _events = filtered;
      _lastFetch = DateTime.now();
      _debugLogs.add('Serwer zwrócił: ${newEvents.length} meczów');
      _debugLogs.add('Pasek wyświetla: ${_events.length} meczów');
      if (newEvents.isNotEmpty) {
        final matches = newEvents.whereType<MatchEvent>().toList();
        _debugLogs.add('Meczy z API: ${matches.length}');
        if (matches.isNotEmpty) {
          // Pokaż przykłady drużyn z API
          final homeTeams = matches.take(8).map((e) => e.homeTeam).join(', ');
          _debugLogs.add('Drużyny (home): $homeTeams');
        }
        if (favoriteKeywords != null && favoriteKeywords.isNotEmpty) {
          final normFavs = favoriteKeywords.map((f) => TextUtils.normalize(f)).toList();
          _debugLogs.add('Szukam: ${normFavs.join(", ")}');
          // Sprawdź czy któreś słowo pasuje
          for (final fav in normFavs) {
            final found = matches.where((e) {
              final searchable = TextUtils.normalize("${e.homeTeam} ${e.awayTeam} ${e.competition}");
              return TextUtils.fuzzyMatch(searchable, fav);
            }).toList();
            _debugLogs.add('  "$fav" → ${found.length} trafień');
            if (found.isNotEmpty) {
              _debugLogs.add('    Przykład: ${found.first.homeTeam} vs ${found.first.awayTeam}');
            }
          }
        }
      }
      
      _currentFavorites = favoriteKeywords;
      _currentOnlyFavorites = onlyFavoriteTeams;
      _currentSelectedLeagues = selectedLeagueIds;

      if (_events.any((e) => e.status == EventStatus.live)) {
        _startAutoRefresh();
      } else {
        _stopAutoRefresh();
      }
    } catch (e) {
      _debugLogs.add('BŁĄD: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
       final newEvents = await _service.fetchAllEvents(selectedLeagueIds: _currentSelectedLeagues);
       _events = _filterAndSortEvents(newEvents, _currentFavorites, _currentOnlyFavorites);
       notifyListeners();
       if (!_events.any((e) => e.status == EventStatus.live)) _stopAutoRefresh();
    });
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    super.dispose();
  }

  /// Filtruje tylko "topowe" ligi — bez Białorusi, itp.
  List<SportEvent> _filterTopLeagues(List<SportEvent> list) {
    const topCompetitions = {
      // Piłka nożna
      'premier league', 'ekstraklasa', 'la liga', 'laliga', 'serie a', 'bundesliga',
      'ligue 1', 'champions league', 'europa league', 'liga mistrzów', 'liga europy',
      'eredivisie', 'liga portugal', 'primeira liga', 'super lig', 'superliga',
      // NBA / Koszykówka
      'nba', 'euroleague', 'euroliga', 'plk',
      // Hokej
      'nhl', 'shl', 'liiga',
      // NFL / MLB
      'nfl', 'mlb', 'super bowl',
      // Tenis
      'atp', 'wta', 'wimbledon', 'roland garros', 'us open', 'australian open',
      // F1
      'formula 1', 'formula1', 'f1',
    };

    return list.where((e) {
      if (e is MatchEvent) {
        final comp = e.competition.toLowerCase();
        return topCompetitions.any((top) => comp.contains(top));
      } else if (e is RaceEvent) {
        return true; // F1/WRC zawsze pokazuj
      }
      return false;
    }).toList();
  }

  List<SportEvent> _filterAndSortEvents(List<SportEvent> list, List<String>? favorites, bool onlyFavs) {
    if (onlyFavs && favorites != null && favorites.isNotEmpty) {
      final normalizedFavs = favorites.map((f) => TextUtils.normalize(f)).toList();
      list = list.where((e) {
        if (e is MatchEvent) {
          final searchable = TextUtils.normalize("${e.homeTeam} ${e.awayTeam} ${e.competition}");
          return normalizedFavs.any((f) => TextUtils.fuzzyMatch(searchable, f));
        } else if (e is RaceEvent) {
          final searchable = TextUtils.normalize("${e.raceName} ${e.circuitName}");
          return normalizedFavs.any((f) => TextUtils.fuzzyMatch(searchable, f));
        }
        return false;
      }).toList();
    }

    list.sort((a, b) {
      if (a.status == EventStatus.live && b.status != EventStatus.live) return -1;
      if (a.status != EventStatus.live && b.status == EventStatus.live) return 1;
      return b.date.compareTo(a.date);
    });

    return list;
  }
}
