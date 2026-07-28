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
  }) async {
    if (!force && _lastFetch != null && DateTime.now().difference(_lastFetch!).inMinutes < 5) return;

    _isLoading = true;
    _debugLogs.clear();
    _debugLogs.add('--- DIAGNOSTYKA V8.8 ---');
    _debugLogs.add('Start: ${DateTime.now().toString().split('.')[0]}');
    notifyListeners();

    try {
      final newEvents = await _service.fetchAllEvents(selectedLeagueIds: selectedLeagueIds);
      
      // 1. Filtrujemy pod zainteresowania
      var filtered = _filterAndSortEvents(newEvents, favoriteKeywords, onlyFavoriteTeams);
      
      // 2. TRYB DISCOVERY: Jeśli pusto dla Twoich, ale serwer coś ma -> pokaż hity dnia
      if (filtered.isEmpty && newEvents.isNotEmpty && onlyFavoriteTeams) {
        _debugLogs.add('Discovery Mode: Pokazuję najważniejsze mecze ze świata.');
        // Weź mecze z najwyższą ligą (np. te z logami)
        filtered = newEvents.where((e) => e is MatchEvent && e.homeLogo != null).take(10).toList();
        if (filtered.isEmpty) filtered = newEvents.take(5).toList();
      }

      _events = filtered;
      _lastFetch = DateTime.now();
      _debugLogs.add('Serwer zwrócił: ${newEvents.length} meczów');
      _debugLogs.add('Pasek wyświetla: ${_events.length} meczów');
      
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

  List<SportEvent> _filterAndSortEvents(List<SportEvent> list, List<String>? favorites, bool onlyFavs) {
    if (onlyFavs && favorites != null && favorites.isNotEmpty) {
      final normalizedFavs = favorites.map((f) => TextUtils.normalize(f)).toList();
      list = list.where((e) {
        if (e is MatchEvent) {
          final searchable = TextUtils.normalize("${e.homeTeam} ${e.awayTeam} ${e.competition}");
          return normalizedFavs.any((f) => searchable.contains(f));
        } else if (e is RaceEvent) {
          final searchable = TextUtils.normalize("${e.raceName} ${e.circuitName}");
          return normalizedFavs.any((f) => searchable.contains(f));
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
