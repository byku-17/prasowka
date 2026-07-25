import 'dart:async';
import 'package:flutter/material.dart';
import 'package:prasowka/models/sport_event.dart';
import 'package:prasowka/services/sports_service.dart';

class SportsProvider with ChangeNotifier {
  final SportsService _service = SportsService();
  
  List<SportEvent> _events = [];
  final List<String> _debugLogs = [];
  bool _isLoading = false;
  DateTime? _lastFetch;
  Timer? _refreshTimer;

  List<SportEvent> get events => _events;
  List<String> get debugLogs => _debugLogs;
  bool get isLoading => _isLoading;

  Future<void> fetchEvents({
    List<String>? favoriteKeywords, 
    bool onlyFavoriteTeams = true,
    bool force = false
  }) async {
    // Odświeżamy co 5 minut, chyba że wymuszono (force)
    if (!force && _lastFetch != null && DateTime.now().difference(_lastFetch!).inMinutes < 5) {
      return;
    }

    _isLoading = true;
    _debugLogs.clear();
    _debugLogs.add('--- DIAGNOSTYKA V4.2 ---');
    _debugLogs.add('Start: ${DateTime.now().toString().split('.')[0]}');
    _debugLogs.add('Zainteresowania: ${favoriteKeywords?.join(', ') ?? 'brak'}');
    notifyListeners();

    try {
      final newEvents = await _service.fetchAllEvents();
      _events = _filterAndSortEvents(newEvents, favoriteKeywords, onlyFavoriteTeams);
      _lastFetch = DateTime.now();
      
      _debugLogs.add('Serwer zwrócił: ${newEvents.length} meczów');
      _debugLogs.add('Po filtrach: ${_events.length} meczów');
      
      if (_events.isEmpty && newEvents.isNotEmpty) {
        _debugLogs.add('HINT: Żadne hasło nie pasuje do pobranych danych.');
        if (newEvents.isNotEmpty) {
          final competitions = newEvents.whereType<MatchEvent>().map((e) => e.competition).toSet();
          _debugLogs.add('Dostępne ligi: ${competitions.take(3).join(', ')}');
        }
      }
      
      // Zarządzanie odświeżaniem LIVE
      if (_events.any((e) => e.status == EventStatus.live)) {
        _startAutoRefresh(favoriteKeywords, onlyFavoriteTeams);
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

  void _startAutoRefresh(List<String>? favs, bool onlyFavs) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
       final newEvents = await _service.fetchAllEvents();
       _events = _filterAndSortEvents(newEvents, favs, onlyFavs);
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
    // Filtrowanie wyłącznie po zainteresowaniach (jeśli opcja włączona)
    if (onlyFavs && favorites != null && favorites.isNotEmpty) {
      final normalizedFavs = favorites.map((f) => _normalize(f)).toList();
      list = list.where((e) {
        if (e is MatchEvent) {
          final searchable = _normalize("${e.homeTeam} ${e.awayTeam} ${e.competition}");
          return normalizedFavs.any((f) => searchable.contains(f));
        } else if (e is RaceEvent) {
          final searchable = _normalize("${e.raceName} ${e.circuitName}");
          return normalizedFavs.any((f) => searchable.contains(f));
        }
        return false;
      }).toList();
    }

    // Sortowanie: LIVE > Data (najnowsze na górze)
    list.sort((a, b) {
      if (a.status == EventStatus.live && b.status != EventStatus.live) return -1;
      if (a.status != EventStatus.live && b.status == EventStatus.live) return 1;

      // Priorytet dla dopasowania 1:1 (jeśli nazwa dokładnie taka jak hasło)
      if (favorites != null && favorites.isNotEmpty) {
         final normalizedFavs = favorites.map((f) => _normalize(f)).toList();
         bool aExact = false;
         bool bExact = false;
         if (a is MatchEvent) aExact = normalizedFavs.any((f) => _normalize(a.homeTeam) == f || _normalize(a.awayTeam) == f);
         if (b is MatchEvent) bExact = normalizedFavs.any((f) => _normalize(b.homeTeam) == f || _normalize(b.awayTeam) == f);
         if (aExact && !bExact) return -1;
         if (!aExact && bExact) return 1;
      }

      return b.date.compareTo(a.date);
    });

    return list;
  }

  String _normalize(String text) {
    var str = text.toLowerCase();
    const polish = 'ąćęłńóśźż';
    const latin = 'acelnoszz';
    for (int i = 0; i < polish.length; i++) {
      str = str.replaceAll(polish[i], latin[i]);
    }
    // Usuwamy zbędne dodatki dla lepszego dopasowania
    str = str.replaceAll('fc ', '').replaceAll(' ks ', '').replaceAll(' gks ', '').replaceAll(' pko bp ', '');
    return str.trim();
  }
}
