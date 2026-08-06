import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:prasowka/models/sport_event.dart';
import 'package:prasowka/services/sports_service.dart';
import 'package:prasowka/utils/text_utils.dart';

const String _pinnedBoxName = 'pinned_matches';
const String _sportsCacheBoxName = 'sports_cache';
const Duration _liveTtl = Duration(minutes: 1);
const Duration _normalTtl = Duration(minutes: 15);

class _LeagueCacheEntry {
  final List<SportEvent> events;
  final DateTime fetchedAt;
  final String source;

  _LeagueCacheEntry({
    required this.events,
    required this.fetchedAt,
    required this.source,
  });

  bool isExpired(bool hasLive) {
    final ttl = hasLive ? _liveTtl : _normalTtl;
    return DateTime.now().difference(fetchedAt) > ttl;
  }

  Map<String, dynamic> toMap() => {
    'events': events.map((e) => e.toMap()).toList(),
    'fetchedAt': fetchedAt.toIso8601String(),
    'source': source,
  };

  factory _LeagueCacheEntry.fromMap(Map m) => _LeagueCacheEntry(
    events: (m['events'] as List).map((e) => SportEvent.fromMap(e)).toList(),
    fetchedAt: DateTime.parse(m['fetchedAt']),
    source: m['source'] ?? '',
  );
}

class SportsProvider with ChangeNotifier {
  final SportsService _service = SportsService();
  
  final Map<String, _LeagueCacheEntry> _leagueCache = {};
  final List<String> _debugLogs = [];
  bool _isLoading = false;
  DateTime? _lastFetch;
  Timer? _refreshTimer;
  List<String>? _currentSelectedLeagues;

  List<SportEvent> get events {
    final all = <SportEvent>[];
    for (final entry in _leagueCache.values) {
      all.addAll(entry.events);
    }
    return all;
  }
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
    final currentEvents = events;
    final hasLive = currentEvents.any((e) => e.status == EventStatus.live);
    final hasFavorites = onlyFavoriteTeams && favoriteKeywords != null && favoriteKeywords.isNotEmpty;
    final ttl = hasLive ? 1 : (hasFavorites ? 30 : 15);

    if (!force && _lastFetch != null && DateTime.now().difference(_lastFetch!).inMinutes < ttl) {
      return Future.value();
    }

    _isLoading = true;
    _debugLogs.clear();
    _debugLogs.add('--- DIAGNOSTYKA V9.1 ---');
    _debugLogs.add('Start: ${DateTime.now().toString().split('.')[0]} (TTL: ${ttl}min)');
    _debugLogs.add('Cache: ${_leagueCache.length} lig w cache');
    notifyListeners();

    return _performFetch(favoriteKeywords, onlyFavoriteTeams, selectedLeagueIds);
  }

  Future<void> _performFetch(List<String>? favoriteKeywords, bool onlyFavoriteTeams, List<String>? selectedLeagueIds) async {
    try {
      final newEvents = await _service.fetchAllEvents(selectedLeagueIds: selectedLeagueIds);

      // Cache per competition
      for (final event in newEvents) {
        final competition = event is MatchEvent ? event.competition : (event is RaceEvent ? 'races' : 'unknown');
        _leagueCache[competition] = _LeagueCacheEntry(
          events: newEvents.where((e) {
            if (e is MatchEvent) return e.competition == competition;
            if (e is RaceEvent) return competition == 'races';
            return false;
          }).toList(),
          fetchedAt: DateTime.now(),
          source: event.id.split('_').first,
        );
      }

      // Agreguj z cache (bez wygasłych)
      final currentEvents = events;
      final hasLive = currentEvents.any((e) => e.status == EventStatus.live);

      // Usuń wygasłe wpisy
      _leagueCache.removeWhere((key, entry) => entry.isExpired(hasLive));

      // 1. Filtrujemy pod zainteresowania
      List<SportEvent> filtered;
      if (favoriteKeywords != null && favoriteKeywords.isNotEmpty) {
        filtered = _filterAndSortEvents(currentEvents, favoriteKeywords, true);
        _debugLogs.add('Ulubione: ${favoriteKeywords.join(", ")}');
        _debugLogs.add('Po filtrze: ${filtered.length} z ${currentEvents.length} meczów');
      } else if (onlyFavoriteTeams) {
        filtered = _filterTopLeagues(currentEvents);
        _debugLogs.add('Top ligi: ${filtered.length} z ${currentEvents.length}');
      } else {
        filtered = currentEvents;
        _debugLogs.add('Wszystko: ${filtered.length} meczów');
      }

      // 2. DISCOVERY MODE
      if (filtered.isEmpty && currentEvents.isNotEmpty) {
        final topMatches = _filterTopLeagues(currentEvents).take(5).toList();
        if (topMatches.isNotEmpty) {
          _debugLogs.add('Discovery Mode: Pokazuję top ${topMatches.length} meczów.');
          filtered = topMatches;
        } else {
          _debugLogs.add('Discovery Mode: Pokazuję wszystkie mecze z API.');
          filtered = currentEvents.take(10).toList();
        }
      }

      // Zapisz do cache Hive
      _saveCacheToHive();

      _lastFetch = DateTime.now();
      _debugLogs.add('Cache lig: ${_leagueCache.length}');
      _debugLogs.add('Pasek wyświetla: ${filtered.length} meczów');
      if (filtered.isNotEmpty) {
        final matches = filtered.whereType<MatchEvent>().toList();
        _debugLogs.add('Meczy: ${matches.length}');
        if (matches.isNotEmpty) {
          final homeTeams = matches.take(8).map((e) => e.homeTeam).join(', ');
          _debugLogs.add('Drużyny (home): $homeTeams');
        }
        if (favoriteKeywords != null && favoriteKeywords.isNotEmpty) {
          final normFavs = favoriteKeywords.map((f) => TextUtils.normalize(f)).toList();
          _debugLogs.add('Szukam: ${normFavs.join(", ")}');
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
      
      _currentSelectedLeagues = selectedLeagueIds;

      if (events.any((e) => e.status == EventStatus.live)) {
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
       for (final event in newEvents) {
         final competition = event is MatchEvent ? event.competition : (event is RaceEvent ? 'races' : 'unknown');
         _leagueCache[competition] = _LeagueCacheEntry(
           events: newEvents.where((e) {
             if (e is MatchEvent) return e.competition == competition;
             if (e is RaceEvent) return competition == 'races';
             return false;
           }).toList(),
           fetchedAt: DateTime.now(),
           source: event.id.split('_').first,
         );
       }
       _lastFetch = DateTime.now();
       notifyListeners();
       if (!events.any((e) => e.status == EventStatus.live)) _stopAutoRefresh();
    });
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _saveCacheToHive() async {
    try {
      if (!Hive.isBoxOpen(_sportsCacheBoxName)) {
        await Hive.openBox(_sportsCacheBoxName);
      }
      final box = Hive.box(_sportsCacheBoxName);
      final data = _leagueCache.map((k, v) => MapEntry(k, v.toMap()));
      await box.put('leagueCache', data);
      await box.put('lastFetch', _lastFetch?.toIso8601String());
    } catch (_) {}
  }

  Future<void> loadCacheFromHive() async {
    try {
      if (!Hive.isBoxOpen(_sportsCacheBoxName)) {
        await Hive.openBox(_sportsCacheBoxName);
      }
      final box = Hive.box(_sportsCacheBoxName);
      final data = box.get('leagueCache');
      if (data is Map) {
        for (final entry in data.entries) {
          try {
            _leagueCache[entry.key] = _LeagueCacheEntry.fromMap(entry.value);
          } catch (_) {}
        }
      }
      final lastFetchStr = box.get('lastFetch');
      if (lastFetchStr != null) {
        _lastFetch = DateTime.tryParse(lastFetchStr);
      }
      notifyListeners();
    } catch (_) {}
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
