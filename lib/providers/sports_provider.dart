import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:prasowka/models/sport_event.dart';
import 'package:prasowka/services/sports_service.dart';
import 'package:prasowka/services/notification_history.dart';
import 'package:prasowka/utils/text_utils.dart';

const String _pinnedBoxName = 'pinned_matches';
const String _sportsCacheBoxName = 'sports_cache';
const Duration _liveTtl = Duration(minutes: 6);
const Duration _normalTtl = Duration(minutes: 15);
const Duration _finishedTtl = Duration(hours: 12);

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
    final age = DateTime.now().difference(fetchedAt);
    final allFinished = events.every((e) => e.status == EventStatus.finished);

    if (allFinished) return age > _finishedTtl;
    if (hasLive) return age > _liveTtl;
    return age > _normalTtl;
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
  List<SportEvent> _filteredEvents = [];
  final List<String> _debugLogs = [];
  bool _isLoading = false;
  DateTime? _lastFetch;
  Timer? _refreshTimer;
  List<String>? _currentFavorites;
  bool _currentOnlyFavorites = true;
  List<String>? _currentSelectedLeagues;
  final Map<String, String> _previousScores = {};
  bool _initialScoreLoad = true;

  List<SportEvent> get events => _filteredEvents;
  List<String> get debugLogs => _debugLogs;
  bool get isLoading => _isLoading;
  DateTime? get lastFetch => _lastFetch;

  List<SportEvent> _allCachedEvents() {
    final all = <SportEvent>[];
    final now = DateTime.now();
    for (final entry in _leagueCache.values) {
      final age = now.difference(entry.fetchedAt);
      for (final event in entry.events) {
        if (event is MatchEvent) {
          DataFreshness f;
          if (age < const Duration(minutes: 2)) {
            f = DataFreshness.fresh;
          } else if (age < const Duration(minutes: 15)) {
            f = DataFreshness.cached;
          } else if (age < const Duration(minutes: 60)) {
            f = DataFreshness.stale;
          } else {
            f = DataFreshness.unavailable;
          }
          all.add(MatchEvent(
            id: event.id,
            type: event.type,
            date: event.date,
            status: event.status,
            homeTeam: event.homeTeam,
            awayTeam: event.awayTeam,
            score: event.score,
            competition: event.competition,
            homeLogo: event.homeLogo,
            awayLogo: event.awayLogo,
            time: event.time,
            freshness: f,
            fetchedAtUtc: entry.fetchedAt.toUtc(),
          ));
        } else {
          all.add(event);
        }
      }
    }
    return all;
  }

  void _applyFilters() {
    // Usuń wygasłe wpisy
    final probeAll = _allCachedEvents();
    final hasLive = probeAll.any((e) => e.status == EventStatus.live);
    _leagueCache.removeWhere((key, entry) => entry.isExpired(hasLive));

    // Oblicz przefiltrowane po cleanup
    final allEvents = _allCachedEvents();

    if (_currentFavorites != null && _currentFavorites!.isNotEmpty) {
      _filteredEvents = _filterAndSortEvents(allEvents, _currentFavorites, _currentOnlyFavorites);
    } else if (_currentOnlyFavorites) {
      _filteredEvents = _filterTopLeagues(allEvents);
    } else {
      _filteredEvents = allEvents;
    }

    // Gdy ulubione nie pasują do żadnego meczu — pasek jest pusty
    // UI wyświetla "Brak meczów"
  }
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
    // Zapisz aktualne filtry (używane przez _applyFilters)
    _currentFavorites = favoriteKeywords;
    _currentOnlyFavorites = onlyFavoriteTeams;

    final currentEvents = _allCachedEvents();
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

    return _performFetch(selectedLeagueIds);
  }

  Future<void> _performFetch(List<String>? selectedLeagueIds) async {
    try {
      _debugLogs.add('SportDB key: ${_service.sportDbKeyStatus}');
      _debugLogs.add('Ligi: ${selectedLeagueIds?.length ?? "ALL"}');
      _debugLogs.add('Ulubione: ${_currentFavorites?.join(", ") ?? "brak"}');

      final newEvents = await _service.fetchAllEvents(selectedLeagueIds: selectedLeagueIds);

      // Dodaj logi z serwisu
      for (final log in _service.lastLogs) {
        _debugLogs.add('  $log');
      }

      _debugLogs.add('Pobrano z API: ${newEvents.length} eventów');

      _updateCache(newEvents);

      _lastFetch = DateTime.now();
      _saveCacheToHive();
      _debugLogs.add('Cache lig: ${_leagueCache.length}');
      _debugLogs.add('Cache eventów: ${_allCachedEvents().length}');
      _debugLogs.add('Pasek wyświetla: ${_filteredEvents.length} meczów');
      if (_filteredEvents.isNotEmpty) {
        final matches = _filteredEvents.whereType<MatchEvent>().toList();
        _debugLogs.add('Meczy: ${matches.length}');
        if (matches.isNotEmpty) {
          final homeTeams = matches.take(8).map((e) => e.homeTeam).join(', ');
          _debugLogs.add('Drużyny (home): $homeTeams');
        }
        if (_currentFavorites != null && _currentFavorites!.isNotEmpty) {
          final normFavs = _currentFavorites!.map((f) => TextUtils.normalize(f)).toList();
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
      } else {
        _debugLogs.add('Brak eventów po filtrach!');
        _debugLogs.add('Wszystkich w cache: ${_allCachedEvents().length}');
      }
      
      _currentSelectedLeagues = selectedLeagueIds;

      if (_filteredEvents.any((e) => e.status == EventStatus.live)) {
        _startAutoRefresh();
      } else {
        _stopAutoRefresh();
      }
    } catch (e, stack) {
      _debugLogs.add('BŁĄD: $e');
      _debugLogs.add('Stack: ${stack.toString().split('\n').take(3).join(' | ')}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Aktualizuje cache i stosuje filtry — wspólne dla _performFetch i auto-refresh
  void _updateCache(List<SportEvent> newEvents) {
    // Grupuj po konkurencji zamiast O(N×C)
    final Map<String, List<SportEvent>> grouped = {};
    for (final event in newEvents) {
      final competition = event is MatchEvent ? event.competition : (event is RaceEvent ? 'races' : 'unknown');
      grouped.putIfAbsent(competition, () => []).add(event);
    }
    final now = DateTime.now();
    for (final entry in grouped.entries) {
      _leagueCache[entry.key] = _LeagueCacheEntry(
        events: entry.value,
        fetchedAt: now,
        source: entry.value.first.id.split('_').first,
      );
    }
    final allNow = _allCachedEvents();
    final hasLive = allNow.any((e) => e.status == EventStatus.live);
    _leagueCache.removeWhere((key, entry) => entry.isExpired(hasLive));
    _applyFilters();

    // Wykrywanie zmiany wyniku (foreground goal detection)
    if (!_initialScoreLoad) {
      _detectScoreChanges(allNow);
    }
    _initialScoreLoad = false;

    // Zapisz aktualne wyniki
    for (final event in allNow) {
      if (event is MatchEvent && event.status == EventStatus.live) {
        _previousScores[event.id] = event.score;
      }
    }
  }

  void _detectScoreChanges(List<SportEvent> events) {
    if (_currentFavorites == null || _currentFavorites!.isEmpty) return;
    final normalizedFavs = _currentFavorites!.map((f) => TextUtils.normalize(f)).toList();

    for (var event in events) {
      if (event is! MatchEvent) continue;
      if (event.status != EventStatus.live) continue;

      // Sprawdź czy to mecz mojej drużyny
      final searchable = TextUtils.normalize("${event.homeTeam} ${event.awayTeam} ${event.competition}");
      if (!normalizedFavs.any((f) => TextUtils.fuzzyMatch(searchable, f))) continue;

      final prevScore = _previousScores[event.id];
      if (prevScore != null && prevScore != event.score && prevScore.isNotEmpty) {
        _showForegroundGoalNotification(event, prevScore, event.score);
      }
    }
  }

  void _showForegroundGoalNotification(MatchEvent event, String prevScore, String newScore) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'sowa_sport',
        'Sowa Sport',
        channelDescription: 'Powiadomienia o meczach Twoich drużyn',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        groupKey: 'sowa_sport_group',
      );
      const details = NotificationDetails(android: androidDetails);
      final plugin = FlutterLocalNotificationsPlugin();

      await plugin.show(
        id: event.id.hashCode.abs(),
        title: '⚽ GOL! — ${event.competition}',
        body: '${event.homeTeam} $newScore ${event.awayTeam}',
        notificationDetails: details,
      );

      await NotificationHistory().add(NotificationEntry(
        id: 'sport_fg_${event.id}',
        title: '⚽ GOL! — ${event.competition}',
        body: '${event.homeTeam} $newScore ${event.awayTeam}',
        timestamp: DateTime.now(),
        type: 'sport',
      ));
    } catch (e) {
      debugPrint('Sowa SportsProvider: Błąd powiadomienia o golu: $e');
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
       final newEvents = await _service.fetchAllEvents(selectedLeagueIds: _currentSelectedLeagues);
       _updateCache(newEvents);
       _lastFetch = DateTime.now();
       notifyListeners();
       if (!_filteredEvents.any((e) => e.status == EventStatus.live)) _stopAutoRefresh();
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
      // Wczytaj favoriteTeams z Hive, żeby _applyFilters() miało dostęp
      // do ulubionych od razu (nie czeka na ScoresBar.fetchEvents)
      if (!Hive.isBoxOpen('settings')) {
        await Hive.openBox('settings');
      }
      final settingsBox = Hive.box('settings');
      final favs = List<String>.from(settingsBox.get('favoriteTeams', defaultValue: <String>[]));
      final onlyFavs = settingsBox.get('onlyFavoriteTeams', defaultValue: true) as bool;
      if (favs.isNotEmpty) {
        _currentFavorites = favs;
        _currentOnlyFavorites = onlyFavs;
      }
      _applyFilters();
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
      // Siatkówka
      'plusliga', 'plus liga',
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
