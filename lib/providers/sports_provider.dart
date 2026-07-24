import 'dart:async';
import 'package:flutter/material.dart';
import 'package:prasowka/models/sport_event.dart';
import 'package:prasowka/services/sports_service.dart';

class SportsProvider with ChangeNotifier {
  final SportsService _service = SportsService();
  
  List<SportEvent> _events = [];
  List<String> _debugLogs = [];
  bool _isLoading = false;
  DateTime? _lastFetch;
  Timer? _refreshTimer;

  List<SportEvent> get events => _events;
  List<String> get debugLogs => _debugLogs;
  bool get isLoading => _isLoading;

  Future<void> fetchEvents({
    List<String>? favoriteKeywords, 
    List<String>? enabledSports, 
    List<String>? enabledLeagues,
    bool onlyFavoriteTeams = false,
    bool force = false
  }) async {
    // Odświeżamy rzadziej (co 5 minut), aby nie wyczerpać darmowych limitów
    if (!force && _lastFetch != null && DateTime.now().difference(_lastFetch!).inMinutes < 5) {
      debugPrint('Sowa Sports: Odświeżanie pominięte (Limit czasu 5 min)');
      return;
    }

    _isLoading = true;
    _debugLogs.clear();
    _debugLogs.add('--- DIAGNOSTYKA ---');
    _debugLogs.add('Start: ${DateTime.now().toString().split('.')[0]}');
    _debugLogs.add('Dyscypliny: ${enabledSports?.join(', ') ?? 'wszystkie'}');
    notifyListeners();

    try {
      final newEvents = await _service.fetchAllEvents(
        enabledSports: enabledSports,
        enabledLeagues: enabledLeagues,
      );
      
      _events = _filterAndSortEvents(newEvents, favoriteKeywords, enabledSports, onlyFavoriteTeams);
      _lastFetch = DateTime.now();
      _debugLogs.add('Serwer: Znaleziono ${newEvents.length} zdarzeń');
      _debugLogs.add('Po filtrach: ${_events.length} zdarzeń');
      
      if (_events.isEmpty) {
        _debugLogs.add('HINT: Sprawdź czy ligi/kluby grają DZIŚ lub WCZORAJ.');
      }
      
      // Zarządzanie odświeżaniem LIVE
      if (_events.any((e) => e.status == EventStatus.live)) {
        _startAutoRefresh(favoriteKeywords, enabledSports, enabledLeagues, onlyFavoriteTeams);
      } else {
        _stopAutoRefresh();
      }
    } catch (e) {
      debugPrint('Sowa Sports Provider Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startAutoRefresh(List<String>? favs, List<String>? sports, List<String>? leagues, bool onlyFavs) {
    _refreshTimer?.cancel();
    // Odświeżanie co 5 minut w przypadku meczów LIVE
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
       debugPrint('Sowa Sports: Automatyczne odświeżanie LIVE...');
       final newEvents = await _service.fetchAllEvents(enabledLeagues: leagues, enabledSports: sports);
       _events = _filterAndSortEvents(newEvents, favs, sports, onlyFavs);
       notifyListeners();
       
       if (!_events.any((e) => e.status == EventStatus.live)) {
         _stopAutoRefresh();
       }
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

  List<SportEvent> _filterAndSortEvents(List<SportEvent> list, List<String>? favorites, List<String>? enabledSports, bool onlyFavs) {
    // 1. Filtrowanie po "Tylko ulubione"
    if (onlyFavs && favorites != null && favorites.isNotEmpty) {
      final lowerFavs = favorites.map((f) => f.toLowerCase()).toList();
      list = list.where((e) {
        if (e is MatchEvent) {
          return lowerFavs.any((f) => e.homeTeam.toLowerCase().contains(f) || e.awayTeam.toLowerCase().contains(f));
        } else if (e is RaceEvent) {
          return lowerFavs.any((f) => e.raceName.toLowerCase().contains(f));
        }
        return false;
      }).toList();
    }

    // 2. Sortowanie: LIVE > Ulubione > Czas
    list.sort((a, b) {
      // Priorytet LIVE
      if (a.status == EventStatus.live && b.status != EventStatus.live) return -1;
      if (a.status != EventStatus.live && b.status == EventStatus.live) return 1;

      // Priorytet Ulubione
      if (favorites != null && favorites.isNotEmpty) {
        final lowerFavs = favorites.map((f) => f.toLowerCase()).toList();
        bool aIsFav = false;
        bool bIsFav = false;
        
        if (a is MatchEvent) aIsFav = lowerFavs.any((f) => a.homeTeam.toLowerCase().contains(f) || a.awayTeam.toLowerCase().contains(f));
        if (b is MatchEvent) bIsFav = lowerFavs.any((f) => b.homeTeam.toLowerCase().contains(f) || b.awayTeam.toLowerCase().contains(f));
        
        if (aIsFav && !bIsFav) return -1;
        if (!aIsFav && bIsFav) return 1;
      }

      // Chronologia
      return a.date.compareTo(b.date);
    });

    return list;
  }
}
