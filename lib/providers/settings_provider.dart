import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:prasowka/models/news_category.dart';
import 'package:prasowka/models/news_source.dart';
import 'package:prasowka/services/storage_service.dart';
import 'package:prasowka/services/background_service.dart';
import 'package:prasowka/services/weather_service.dart';

class SettingsProvider with ChangeNotifier {
  static const String settingsBoxName = 'settings';
  static const String sourcesBoxName = 'news_sources_dynamic';
  static const String categoriesBoxName = 'news_categories_dynamic';
  
  static const String themeKey = 'themeMode';
  static const String activeCategoriesKey = 'activeCategoryIds';
  static const String sourcesEnabledKey = 'activeSourceIds';
  static const String teamsKey = 'favoriteTeams';
  static const String categoryOrderKey = 'categoryOrder';
  static const String notificationsKey = 'notificationsEnabled';
  static const String onboardingKey = 'onboardingCompleted';
  static const String lastTabIndexKey = 'lastTabIndex';
  static const String sportsBarKey = 'showSportsBar';
  static const String onlyFavoriteTeamsKey = 'onlyFavoriteTeams';
  static const String preferredCityKey = 'preferredCity';
  static const String cityLatKey = 'cityLatitude';
  static const String cityLonKey = 'cityLongitude';
  static const String selectedLeaguesKey = 'selectedLeagueIds';

  ThemeMode _themeMode = ThemeMode.system;
  List<NewsCategory> _allCategories = [];
  List<String> _activeCategoryIds = [];
  List<String> _enabledSourceIds = [];
  List<String> _favoriteTeams = [];
  List<String> _categoryOrder = [];
  List<NewsSource> _allSources = [];
  bool _onlyFavoriteTeams = true; 
  bool _notificationsEnabled = false;
  bool _onboardingCompleted = false;
  bool _showSportsBar = true;
  int _lastTabIndex = 0;
  String _preferredCity = 'Warszawa';
  double _cityLatitude = 52.2297;
  double _cityLongitude = 21.0122;
  List<String> _selectedLeagueIds = [];

  ThemeMode get themeMode => _themeMode;
  List<NewsCategory> get allCategories => _allCategories;
  List<String> get activeCategoryIds => _activeCategoryIds;
  List<String> get enabledSourceIds => _enabledSourceIds;
  List<String> get favoriteTeams => _favoriteTeams;
  List<NewsSource> get allSources => _allSources;
  bool get onlyFavoriteTeams => _onlyFavoriteTeams;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get onboardingCompleted => _onboardingCompleted;
  bool get showSportsBar => _showSportsBar;
  int get lastTabIndex => _lastTabIndex;
  String get preferredCity => _preferredCity;
  CityCoordinates get cityCoordinates => CityCoordinates(name: _preferredCity, latitude: _cityLatitude, longitude: _cityLongitude);
  List<String> get selectedLeagueIds => List.unmodifiable(_selectedLeagueIds);

  Future<void> init() async {
    debugPrint('Sowa Settings: Inicjalizacja V4.5...');
    
    await StorageService().init();
    final settingsBox = await Hive.openBox(settingsBoxName);

    // 1. Inicjalizacja Kategorii
    final categoriesBox = await Hive.openBox<NewsCategory>(categoriesBoxName);
    if (categoriesBox.isEmpty) {
      await categoriesBox.putAll({for (var c in NewsCategory.defaultCategories) c.id: c});
    }
    for (final cat in NewsCategory.defaultCategories) {
      if (!categoriesBox.containsKey(cat.id)) {
        await categoriesBox.put(cat.id, cat);
      }
    }
    _allCategories = categoriesBox.values.toList();

    // 2. Inicjalizacja Źródeł
    final sourcesBox = await Hive.openBox<NewsSource>(sourcesBoxName);
    if (sourcesBox.isEmpty || sourcesBox.length < (NewsSource.defaultSources.length * 0.9)) {
      await resetToDefaultSources();
    } else {
      _allSources = sourcesBox.values.toList();
      // Dodaj brakujące domyślne źródła (np. nowe źródła miejskie)
      final existingIds = _allSources.map((s) => s.id).toSet();
      final missingDefaults = NewsSource.defaultSources.where((s) => !existingIds.contains(s.id));
      if (missingDefaults.isNotEmpty) {
        for (final src in missingDefaults) {
          await sourcesBox.put(src.id, src);
        }
        _allSources = sourcesBox.values.toList();
      }
    }

    // 3. Ustawienia ogólne
    final themeIndex = settingsBox.get(themeKey, defaultValue: ThemeMode.system.index);
    _themeMode = (themeIndex is int && themeIndex >= 0 && themeIndex < ThemeMode.values.length)
        ? ThemeMode.values[themeIndex]
        : ThemeMode.system;
    _onboardingCompleted = settingsBox.get(onboardingKey, defaultValue: false);
    _showSportsBar = settingsBox.get(sportsBarKey, defaultValue: true);
    _onlyFavoriteTeams = settingsBox.get(onlyFavoriteTeamsKey, defaultValue: true);
    _lastTabIndex = settingsBox.get(lastTabIndexKey, defaultValue: 0);
    _preferredCity = settingsBox.get(preferredCityKey, defaultValue: 'Warszawa');
    _cityLatitude = settingsBox.get(cityLatKey, defaultValue: 52.2297);
    _cityLongitude = settingsBox.get(cityLonKey, defaultValue: 21.0122);
    
    // 4a. Wybrane ligi sportowe
    _selectedLeagueIds = List<String>.from(settingsBox.get(
      selectedLeaguesKey,
      defaultValue: <String>[], 
    ));

    // 4. Kolejność kategorii
    _categoryOrder = List<String>.from(settingsBox.get(
      categoryOrderKey,
      defaultValue: _allCategories.map((c) => c.id).toList(),
    ));
    bool orderChanged = false;
    for (final cat in _allCategories) {
      if (!_categoryOrder.contains(cat.id)) {
        _categoryOrder.add(cat.id);
        orderChanged = true;
      }
    }
    _categoryOrder.removeWhere((id) => !_allCategories.any((c) => c.id == id));
    if (orderChanged) {
      await settingsBox.put(categoryOrderKey, _categoryOrder);
    }

    // 5. Aktywne kategorie
    _activeCategoryIds = List<String>.from(settingsBox.get(
      activeCategoriesKey,
      defaultValue: _allCategories.map((c) => c.id).toList(),
    ));

    bool changed = false;
    for (final cat in _allCategories) {
      if (!_activeCategoryIds.contains(cat.id)) {
        _activeCategoryIds.add(cat.id);
        changed = true;
      }
    }
    if (changed) {
      await Hive.box(settingsBoxName).put(activeCategoriesKey, _activeCategoryIds);
    }

    // 5. Włączone źródła
    _enabledSourceIds = List<String>.from(settingsBox.get(
      sourcesEnabledKey,
      defaultValue: _allSources.where((s) => s.isDefault).map((s) => s.id).toList(),
    ));

    if (_enabledSourceIds.isEmpty && _allSources.isNotEmpty) {
      _enabledSourceIds = _allSources.where((s) => s.isDefault).map((s) => s.id).toList();
      await saveEnabledSources();
    }

    // 6. Zainteresowania
    _favoriteTeams = List<String>.from(settingsBox.get(teamsKey, defaultValue: <String>[]));

    // 7. Powiadomienia
    _notificationsEnabled = settingsBox.get(notificationsKey, defaultValue: false);
    await BackgroundService().init();
    if (_notificationsEnabled) {
      await BackgroundService().registerPeriodicTask();
    }

    await _ensureNewSourcesRegistered();
    notifyListeners();
    debugPrint('Sowa Settings: Gotowe (V4.5 Clean)');
  }

  Future<void> _ensureNewSourcesRegistered() async {
    final box = await Hive.openBox<NewsSource>(sourcesBoxName);
    final newIds = ['natemat_pl', 'gryonline_promocje', 'purepc_promocje', 'lowcygier', 'kodpromo', 'warszawa_pl', 'warszawa_wpigulce', 'uw_news'];
    for (final id in newIds) {
      if (!box.containsKey(id)) {
        final source = NewsSource.defaultSources.firstWhere((s) => s.id == id, orElse: () => NewsSource.defaultSources.first);
        await box.put(id, source);
      }
    }
    _allSources = box.values.toList();
  }

  Future<void> toggleNotifications(bool enabled) async {
    if (enabled) {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    }
    _notificationsEnabled = enabled;
    await Hive.box(settingsBoxName).put(notificationsKey, enabled);
    if (enabled) {
      await BackgroundService().registerPeriodicTask();
    } else {
      await BackgroundService().cancelAllTasks();
    }
    notifyListeners();
  }

  Future<void> addKeyword(String keyword) async {
    final t = keyword.trim();
    if (t.isEmpty || _favoriteTeams.any((element) => element.toLowerCase() == t.toLowerCase())) return;
    _favoriteTeams.add(t);
    await Hive.box(settingsBoxName).put(teamsKey, _favoriteTeams);
    
    final sourceId = 'google_news_${t.toLowerCase().replaceAll(' ', '_')}';
    final googleSource = NewsSource(
      id: sourceId,
      name: 'Google News: $t',
      rssUrl: 'https://news.google.com/rss/search?q=${Uri.encodeComponent(t)}&hl=pl&gl=PL&ceid=PL:pl',
      categoryId: 'all',
    );
    await addCustomSource(googleSource);
    notifyListeners();
  }

  Future<void> removeKeyword(String t) async {
    _favoriteTeams.remove(t);
    await Hive.box(settingsBoxName).put(teamsKey, _favoriteTeams);
    final sourceId = 'google_news_${t.toLowerCase().replaceAll(' ', '_')}';
    await deleteSource(sourceId);
    notifyListeners();
  }

  Future<void> addCustomSource(NewsSource source) async {
    final box = Hive.box<NewsSource>(sourcesBoxName);
    await box.put(source.id, source);
    _allSources = List<NewsSource>.from(box.values);
    _enabledSourceIds.add(source.id);
    await saveEnabledSources();
    notifyListeners();
  }

  Future<void> deleteSource(String id) async {
    final box = Hive.box<NewsSource>(sourcesBoxName);
    await box.delete(id);
    _allSources = List<NewsSource>.from(box.values);
    _enabledSourceIds.remove(id);
    await saveEnabledSources();
    notifyListeners();
  }

  Future<void> resetToDefaultSources() async {
    final box = Hive.box<NewsSource>(sourcesBoxName);
    await box.clear();
    await StorageService().clearAllCache();
    await box.putAll({for (var s in NewsSource.defaultSources) s.id: s});
    _allSources = List<NewsSource>.from(box.values);
    _enabledSourceIds = _allSources.where((s) => s.isDefault).map((s) => s.id).toList();
    await saveEnabledSources();
    notifyListeners();
  }

  Future<void> clearNewsCache() async {
    await StorageService().clearAllCache();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await Hive.box(settingsBoxName).put(themeKey, mode.index);
    notifyListeners();
  }

  Future<void> toggleCategory(String id) async {
    _activeCategoryIds.contains(id) ? _activeCategoryIds.remove(id) : _activeCategoryIds.add(id);
    await Hive.box(settingsBoxName).put(activeCategoriesKey, _activeCategoryIds);
    notifyListeners();
  }

  Future<void> toggleSource(String id) async {
    _enabledSourceIds.contains(id) ? _enabledSourceIds.remove(id) : _enabledSourceIds.add(id);
    await saveEnabledSources();
    notifyListeners();
  }

  Future<void> saveEnabledSources() async {
    await Hive.box(settingsBoxName).put(sourcesEnabledKey, _enabledSourceIds);
  }

  Future<void> toggleAllSourcesInCategory(String catId, bool enable) async {
    final ids = _allSources.where((s) => s.categoryId == catId).map((s) => s.id).toList();
    if (enable) {
      for (var id in ids) { if (!_enabledSourceIds.contains(id)) _enabledSourceIds.add(id); }
    } else {
      _enabledSourceIds.removeWhere((id) => ids.contains(id));
    }
    await saveEnabledSources();
    notifyListeners();
  }

  Future<void> toggleAllSources(bool enable) async {
    _enabledSourceIds = enable ? _allSources.map((s) => s.id).toList() : [];
    await saveEnabledSources();
    notifyListeners();
  }

  Future<void> reorderCategories(int old, int neu) async {
    final item = _categoryOrder.removeAt(old);
    _categoryOrder.insert(neu, item);
    await Hive.box(settingsBoxName).put(categoryOrderKey, _categoryOrder);
    notifyListeners();
  }

  List<NewsCategory> get allCategoriesOrdered {
    List<NewsCategory> ordered = [];
    for (var id in _categoryOrder) {
      final f = _allCategories.where((c) => c.id == id).toList();
      if (f.isNotEmpty) ordered.add(f.first);
    }
    for (var c in _allCategories) {
      if (!ordered.any((o) => o.id == c.id)) ordered.add(c);
    }
    return ordered;
  }

  bool isCategoryActive(String id) => _activeCategoryIds.contains(id);
  bool isSourceActive(String id) => _enabledSourceIds.contains(id);

  List<NewsCategory> get activeCategories {
    return allCategoriesOrdered.where((c) => _activeCategoryIds.contains(c.id)).toList();
  }

  Future<void> setLastTabIndex(int index) async {
    _lastTabIndex = index;
    await Hive.box(settingsBoxName).put(lastTabIndexKey, index);
  }

  Future<void> toggleSportsBar(bool enabled) async {
    _showSportsBar = enabled;
    await Hive.box(settingsBoxName).put(sportsBarKey, enabled);
    notifyListeners();
  }

  Future<void> setOnlyFavoriteTeams(bool val) async {
    _onlyFavoriteTeams = val;
    await Hive.box(settingsBoxName).put(onlyFavoriteTeamsKey, val);
    notifyListeners();
  }

  Future<void> setPreferredCity(String name, double lat, double lon) async {
    final oldCity = _preferredCity;
    _preferredCity = name;
    _cityLatitude = lat;
    _cityLongitude = lon;
    final box = Hive.box(settingsBoxName);
    await box.put(preferredCityKey, name);
    await box.put(cityLatKey, lat);
    await box.put(cityLonKey, lon);

    // Automatycznie przełącz źródła miejskie
    if (oldCity != name) {
      // Wyłącz źródła starego miasta
      final oldSourceIds = NewsSource.cityRssSourceIds[oldCity];
      if (oldSourceIds != null) {
        _enabledSourceIds.removeWhere((id) => oldSourceIds.contains(id));
      }
      // Włącz źródła nowego miasta
      final newSourceIds = NewsSource.cityRssSourceIds[name];
      if (newSourceIds != null) {
        for (final id in newSourceIds) {
          if (!_enabledSourceIds.contains(id)) _enabledSourceIds.add(id);
        }
      }
      await saveEnabledSources();
    }

    notifyListeners();
  }

  Future<void> toggleLeague(String leagueId) async {
    if (_selectedLeagueIds.contains(leagueId)) {
      _selectedLeagueIds.remove(leagueId);
    } else {
      _selectedLeagueIds.add(leagueId);
    }
    await Hive.box(settingsBoxName).put(selectedLeaguesKey, _selectedLeagueIds);
    notifyListeners();
  }

  Future<void> setSelectedLeagues(List<String> ids) async {
    _selectedLeagueIds = List<String>.from(ids);
    await Hive.box(settingsBoxName).put(selectedLeaguesKey, _selectedLeagueIds);
    notifyListeners();
  }

  Future<void> addCustomCategory(String name, IconData icon) async {
    final id = 'custom_${name.toLowerCase().replaceAll(' ', '_')}';
    if (_allCategories.any((c) => c.id == id)) return;
    final newCategory = NewsCategory(id: id, name: name, iconCode: icon.codePoint, isCustom: true);
    final box = Hive.box<NewsCategory>(categoriesBoxName);
    await box.put(id, newCategory);
    _allCategories = box.values.toList();
    _categoryOrder.add(id);
    await Hive.box(settingsBoxName).put(categoryOrderKey, _categoryOrder);
    _activeCategoryIds.add(id);
    await Hive.box(settingsBoxName).put(activeCategoriesKey, _activeCategoryIds);
    notifyListeners();
  }

  Future<void> setSelectedCategories(List<String> ids) async {
    _activeCategoryIds = List<String>.from(ids);
    if (!_activeCategoryIds.contains('all')) _activeCategoryIds.insert(0, 'all');
    await Hive.box(settingsBoxName).put(activeCategoriesKey, _activeCategoryIds);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingCompleted = true;
    await Hive.box(settingsBoxName).put(onboardingKey, true);
    notifyListeners();
  }
}
