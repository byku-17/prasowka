import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:prasowka/models/news_category.dart';
import 'package:prasowka/models/news_source.dart';
import 'package:prasowka/services/storage_service.dart';
import 'package:prasowka/services/background_service.dart';
import 'package:prasowka/services/weather_service.dart';
import 'package:prasowka/services/sync_service.dart';

enum AppThemeVariant { classic, elegantLight, royalPurple, medium, system }

class SettingsProvider with ChangeNotifier {
  static const String settingsBoxName = 'settings';
  static const String sourcesBoxName = 'news_sources_dynamic';
  static const String categoriesBoxName = 'news_categories_dynamic';
  
  static const String themeKey = 'themeMode';
  static const String themeVariantKey = 'themeVariant';
  static const String activeCategoriesKey = 'activeCategoryIds';
  static const String sourcesEnabledKey = 'activeSourceIds';
  static const String teamsKey = 'favoriteTeams';
  static const String keywordsKey = 'userKeywords';
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
  static const String showAllSourcesKey = 'showAllSources';
  static const String readingFontSizeKey = 'readingFontSize';
  static const String readingFontKey = 'readingFont';
  static const String readingFontSystem = 'system';
  static const String readingFontSerif = 'serif';
  static const String readingFontSans = 'sans';
  static const String openArticlesInBrowserKey = 'openArticlesInBrowser';
  static const String showFinishedKey = 'showFinished';
  static const String showUpcomingKey = 'showUpcoming';
  static const String sportResultNotificationsKey = 'sportResultNotifications';
  static const String sportStartNotificationsKey = 'sportStartNotifications';
  static const String notificationStartHourKey = 'notificationStartHour';
  static const String notificationEndHourKey = 'notificationEndHour';
  static const String refreshFrequencyHoursKey = 'refreshFrequencyHours';
  static const String notificationCheckFrequencyHoursKey = 'notificationCheckFrequencyHours';
  static const String alertTypesKey = 'alertTypes';
  static const String alertTypeImportant = 'important';
  static const String alertTypeNew = 'new';
  static const String alertTypeSummary = 'summary';
  static const String wifiOnlyRefreshKey = 'wifiOnlyRefresh';
  static const String articleRetentionDaysKey = 'articleRetentionDays';
  static const String articleSortOrderKey = 'articleSortOrder';
  static const String articleSortLatest = 'latest';
  static const String articleSortUnread = 'unread';
  static const String articleSortPopular = 'popular';
  static const String excludedWordsKey = 'excludedWords';
  static const String articleListLayoutKey = 'articleListLayout';
  static const String articleListLayoutCompact = 'compact';
  static const String articleListLayoutComfortable = 'comfortable';
  static const String imageDisplayModeKey = 'imageDisplayMode';
  static const String imageDisplayAlways = 'always';
  static const String imageDisplayWifiOnly = 'wifi';
  static const String imageDisplayNever = 'never';
  static const String syncScopeKey = 'syncScope';
  static const String autoSyncEnabledKey = 'autoSyncEnabled';
  static const String mainTabSlot1Key = 'mainTabSlot1';
  static const String mainTabSlot2Key = 'mainTabSlot2';

  ThemeMode _themeMode = ThemeMode.system;
  AppThemeVariant _themeVariant = AppThemeVariant.classic;
  List<NewsCategory> _allCategories = [];
  List<String> _activeCategoryIds = [];
  List<String> _enabledSourceIds = [];
  List<String> _favoriteTeams = [];
  List<String> _keywords = [];
  List<String> _categoryOrder = [];
  List<NewsSource> _allSources = [];
  bool _onlyFavoriteTeams = true; 
  bool _notificationsEnabled = false;
  bool _onboardingCompleted = false;
  bool _showSportsBar = true;
  bool _showAllSources = false;
  int _readingFontSize = 16;
  String _readingFont = readingFontSystem;
  bool _openArticlesInBrowser = false;
  bool _showFinished = true;
  bool _showUpcoming = true;
  bool _sportResultNotifications = true;
  bool _sportStartNotifications = true;
  int _notificationStartHour = 7;
  int _notificationEndHour = 21;
  int _refreshFrequencyHours = 0;
  int _notificationCheckFrequencyHours = 1;
  List<String> _alertTypes = [alertTypeImportant];
  bool _wifiOnlyRefresh = false;
  int _articleRetentionDays = 0;
  String _articleSortOrder = articleSortUnread;
  List<String> _excludedWords = [];
  String _articleListLayout = articleListLayoutComfortable;
  String _imageDisplayMode = imageDisplayAlways;
  bool _onWifi = true;
  List<String> _syncScope = List<String>.from(SyncService.allScopes);
  bool _autoSyncEnabled = false;
  int _lastTabIndex = 0;
  String _mainTabSlot1 = 'warsaw';
  String _mainTabSlot2 = 'sport';
  String _preferredCity = 'Warszawa';
  double _cityLatitude = 52.2297;
  double _cityLongitude = 21.0122;
  List<String> _selectedLeagueIds = [];
  StreamSubscription? _connectivitySubscription;

  ThemeMode get themeMode => _themeMode;
  AppThemeVariant get themeVariant => _themeVariant;
  List<NewsCategory> get allCategories => _allCategories;
  List<String> get enabledSourceIds => _enabledSourceIds;
  List<String> get favoriteTeams => _favoriteTeams;
  List<String> get keywords => _keywords;
  List<NewsSource> get allSources => _allSources;
  bool get onlyFavoriteTeams => _onlyFavoriteTeams;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get onboardingCompleted => _onboardingCompleted;
  bool get showSportsBar => _showSportsBar;
  bool get showAllSources => _showAllSources;
  int get readingFontSize => _readingFontSize;
  String get readingFont => _readingFont;
  bool get openArticlesInBrowser => _openArticlesInBrowser;
  bool get showFinished => _showFinished;
  bool get showUpcoming => _showUpcoming;
  bool get sportResultNotifications => _sportResultNotifications;
  bool get sportStartNotifications => _sportStartNotifications;
  int get notificationStartHour => _notificationStartHour;
  int get notificationEndHour => _notificationEndHour;
  int get refreshFrequencyHours => _refreshFrequencyHours;
  int get notificationCheckFrequencyHours => _notificationCheckFrequencyHours;
  List<String> get alertTypes => List.unmodifiable(_alertTypes);
  bool isAlertTypeEnabled(String type) => _alertTypes.contains(type);
  bool get wifiOnlyRefresh => _wifiOnlyRefresh;
  int get articleRetentionDays => _articleRetentionDays;
  String get articleSortOrder => _articleSortOrder;
  List<String> get excludedWords => List.unmodifiable(_excludedWords);
  String get articleListLayout => _articleListLayout;
  String get imageDisplayMode => _imageDisplayMode;
  bool get showImagesNow => _imageDisplayMode == imageDisplayAlways || (_imageDisplayMode == imageDisplayWifiOnly && _onWifi);
  bool get isOnWifiNow => _onWifi;
  List<String> get syncScope => List.unmodifiable(_syncScope);
  bool isSyncScopeEnabled(String scope) => _syncScope.contains(scope);
  bool get autoSyncEnabled => _autoSyncEnabled;
  int get lastTabIndex => _lastTabIndex;
  String get mainTabSlot1 => _mainTabSlot1;
  String get mainTabSlot2 => _mainTabSlot2;
  String get preferredCity => _preferredCity;
  CityCoordinates get cityCoordinates => CityCoordinates(name: _preferredCity, latitude: _cityLatitude, longitude: _cityLongitude);
  List<String> get selectedLeagueIds => List.unmodifiable(_selectedLeagueIds);

  Future<void> init() async {
    debugPrint('Sowa Settings: Inicjalizacja V5.3...');
    
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

    // 2b. Napraw zepsute ustawienia (PRZED odczytem)
    await _fixCorruptedSettings();

    // 3. Ustawienia ogólne
    final themeIndex = settingsBox.get(themeKey, defaultValue: ThemeMode.system.index);
    _themeMode = (themeIndex is int && themeIndex >= 0 && themeIndex < ThemeMode.values.length)
        ? ThemeMode.values[themeIndex]
        : ThemeMode.system;

    final variantIndex = settingsBox.get(themeVariantKey, defaultValue: AppThemeVariant.classic.index);
    _themeVariant = (variantIndex is int && variantIndex >= 0 && variantIndex < AppThemeVariant.values.length)
        ? AppThemeVariant.values[variantIndex]
        : AppThemeVariant.classic;
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

    // 4b. Pokaż wszystkie źródła (nie tylko top)
    _showAllSources = settingsBox.get(showAllSourcesKey, defaultValue: false);

    // 4c. Rozmiar czcionki do czytania
    _readingFontSize = settingsBox.get(readingFontSizeKey, defaultValue: 16);
    _readingFont = settingsBox.get(readingFontKey, defaultValue: readingFontSystem) as String;

    // 4c2. Otwieranie artykułów w zewnętrznej przeglądarce
    _openArticlesInBrowser = settingsBox.get(openArticlesInBrowserKey, defaultValue: false);

    // 4c3. Sport — widoczność i powiadomienia
    _showFinished = settingsBox.get(showFinishedKey, defaultValue: true);
    _showUpcoming = settingsBox.get(showUpcomingKey, defaultValue: true);
    _sportResultNotifications = settingsBox.get(sportResultNotificationsKey, defaultValue: true);
    _sportStartNotifications = settingsBox.get(sportStartNotificationsKey, defaultValue: true);
    _notificationStartHour = _hourSetting(settingsBox, notificationStartHourKey, 7);
    _notificationEndHour = _hourSetting(settingsBox, notificationEndHourKey, 21);
    _refreshFrequencyHours = settingsBox.get(refreshFrequencyHoursKey, defaultValue: 0);
    _notificationCheckFrequencyHours = settingsBox.get(notificationCheckFrequencyHoursKey, defaultValue: 1);
    _alertTypes = List<String>.from(settingsBox.get(alertTypesKey, defaultValue: <String>[alertTypeImportant]));
    _wifiOnlyRefresh = settingsBox.get(wifiOnlyRefreshKey, defaultValue: false) as bool;
    _articleRetentionDays = settingsBox.get(articleRetentionDaysKey, defaultValue: 0) as int;
    _articleSortOrder = settingsBox.get(articleSortOrderKey, defaultValue: articleSortUnread) as String;
    _excludedWords = List<String>.from(settingsBox.get(excludedWordsKey, defaultValue: <String>[]));
    _articleListLayout = settingsBox.get(articleListLayoutKey, defaultValue: articleListLayoutComfortable) as String;
    _imageDisplayMode = settingsBox.get(imageDisplayModeKey, defaultValue: imageDisplayAlways) as String;
    final storedScope = settingsBox.get(syncScopeKey);
    if (storedScope is List && storedScope.isNotEmpty) {
      _syncScope = List<String>.from(storedScope.cast<String>());
    } else {
      _syncScope = List<String>.from(SyncService.allScopes);
    }
    _autoSyncEnabled = settingsBox.get(autoSyncEnabledKey, defaultValue: false) as bool;

    // 4d. Zakładki główne (2 sloty)
    _mainTabSlot1 = settingsBox.get(mainTabSlot1Key, defaultValue: 'warsaw');
    _mainTabSlot2 = settingsBox.get(mainTabSlot2Key, defaultValue: 'sport');
    // Walidacja: upewnij się, że sloty nie są 'all' ani powtórzone
    if (_mainTabSlot1 == 'all' || _mainTabSlot1 == 'api_news') _mainTabSlot1 = 'warsaw';
    if (_mainTabSlot2 == 'all' || _mainTabSlot2 == 'api_news') _mainTabSlot2 = 'sport';
    if (_mainTabSlot1 == _mainTabSlot2) _mainTabSlot2 = 'lifestyle';

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
      await _saveEnabledSources();
    }

    // 5b. Dodaj nowe domyślne źródła (np. portale miejskie), jeśli nie ma ich na liście
    final defaultIds = _allSources.where((s) => s.isDefault).map((s) => s.id).toList();
    final newDefaults = defaultIds.where((id) => !_enabledSourceIds.contains(id)).toList();
    if (newDefaults.isNotEmpty) {
      _enabledSourceIds.addAll(newDefaults);
      await _saveEnabledSources();
    }

    // 6. Zainteresowania
    _favoriteTeams = List<String>.from(settingsBox.get(teamsKey, defaultValue: <String>[]));
    
    // 6b. Keywords (oddzielne od favoriteTeams)
    final storedKeywords = settingsBox.get(keywordsKey);
    if (storedKeywords == null || (storedKeywords as List).isEmpty) {
      // Migracja: skopiuj z favoriteTeams jeśli keywords puste
      _keywords = List<String>.from(_favoriteTeams);
      await settingsBox.put(keywordsKey, _keywords);
    } else {
      _keywords = List<String>.from(storedKeywords);
    }

    // 7. Powiadomienia
    _notificationsEnabled = settingsBox.get(notificationsKey, defaultValue: false);
    if (_notificationsEnabled) {
      await BackgroundService().registerPeriodicTask(frequencyHours: _notificationCheckFrequencyHours);
    }

    await _ensureNewSourcesRegistered();

    // 8. Śledzenie połączenia (dla trybu „obrazki tylko na Wi-Fi")
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      _onWifi = results.any((r) => r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet);
      notifyListeners();
    });
    Connectivity().checkConnectivity().then((results) {
      _onWifi = results.any((r) => r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet);
      notifyListeners();
    });

    notifyListeners();
    debugPrint('Sowa Settings: Gotowe (V4.5 Clean)');
  }

  /// Naprawia ustawienia nadpisane przez sync.
  /// Wymusza wartości tylko dla BRAKUJĄCYCH/nieprawidłowych kluczy —
  /// świadomy wybór użytkownika (np. wyłączony pasek sportowy)
  /// nie jest nadpisywany.
  Future<void> _fixCorruptedSettings() async {
    final box = Hive.box(settingsBoxName);

    // Napraw tylko brakujące/nieprawidłowe wartości — nie nadpisuj jawnego false
    if (box.get(sportsBarKey) == null) {
      await box.put(sportsBarKey, true);
      debugPrint('Settings: fix brakującego showSportsBar = true');
    }
    if (box.get(onlyFavoriteTeamsKey) == null) {
      await box.put(onlyFavoriteTeamsKey, true);
    }
    if (box.get(onboardingKey) == null) {
      await box.put(onboardingKey, true);
    }
    final city = box.get(preferredCityKey);
    if (city == null || city == '' || city is! String) {
      await box.put(preferredCityKey, 'Warszawa');
    }
    final slot1 = box.get(mainTabSlot1Key);
    if (slot1 == null || slot1 == '' || slot1 == 'all' || slot1 == 'api_news') {
      await box.put(mainTabSlot1Key, 'warsaw');
    }
    final slot2 = box.get(mainTabSlot2Key);
    if (slot2 == null || slot2 == '' || slot2 == 'all' || slot2 == 'api_news') {
      await box.put(mainTabSlot2Key, 'sport');
    }
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
      final granted = await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      if (granted == false) return;
    }
    _notificationsEnabled = enabled;
    await Hive.box(settingsBoxName).put(notificationsKey, enabled);
    if (enabled) {
      await BackgroundService().registerPeriodicTask(frequencyHours: _notificationCheckFrequencyHours);
    } else {
      await BackgroundService().cancelAllTasks();
    }
    notifyListeners();
  }

  Future<void> addFavoriteTeam(String team) async {
    final t = team.trim();
    if (t.isEmpty || _favoriteTeams.any((e) => e.toLowerCase() == t.toLowerCase())) return;
    _favoriteTeams.add(t);
    await Hive.box(settingsBoxName).put(teamsKey, _favoriteTeams);
    notifyListeners();
  }

  Future<void> removeFavoriteTeam(String t) async {
    _favoriteTeams.remove(t);
    await Hive.box(settingsBoxName).put(teamsKey, _favoriteTeams);
    notifyListeners();
  }

  static const int maxKeywords = 10;

  Future<void> addKeyword(String keyword) async {
    final t = keyword.trim();
    if (t.isEmpty || _keywords.length >= maxKeywords) return;
    if (_keywords.any((element) => element.toLowerCase() == t.toLowerCase())) return;
    _keywords.add(t);
    await Hive.box(settingsBoxName).put(keywordsKey, _keywords);
    
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
    _keywords.remove(t);
    await Hive.box(settingsBoxName).put(keywordsKey, _keywords);
    final sourceId = 'google_news_${t.toLowerCase().replaceAll(' ', '_')}';
    await deleteSource(sourceId);
    notifyListeners();
  }

  Future<void> addCustomSource(NewsSource source) async {
    final box = Hive.box<NewsSource>(sourcesBoxName);
    await box.put(source.id, source);
    _allSources = List<NewsSource>.from(box.values);
    _enabledSourceIds.add(source.id);
    await _saveEnabledSources();
    notifyListeners();
  }

  Future<void> deleteSource(String id) async {
    final box = Hive.box<NewsSource>(sourcesBoxName);
    await box.delete(id);
    _allSources = List<NewsSource>.from(box.values);
    _enabledSourceIds.remove(id);
    await _saveEnabledSources();
    notifyListeners();
  }

  Future<void> resetToDefaultSources() async {
    final box = Hive.box<NewsSource>(sourcesBoxName);
    await box.clear();
    await StorageService().clearAllCache();
    await box.putAll({for (var s in NewsSource.defaultSources) s.id: s});
    _allSources = List<NewsSource>.from(box.values);
    _enabledSourceIds = _allSources.where((s) => s.isDefault).map((s) => s.id).toList();
    await _saveEnabledSources();
    notifyListeners();
  }

  Future<void> clearNewsCache() async {
    await StorageService().clearAllCache();
    notifyListeners();
  }

  /// Resetuje tylko ustawienia aplikacji do domyślnych wartości.
  Future<void> resetSettings() async {
    await BackgroundService().cancelAllTasks();
    await Hive.box(settingsBoxName).clear();
    await init();
    notifyListeners();
  }

  /// Usuwa wszystkie lokalne dane użytkownika (ustawienia, cache, artykuły,
  /// tagi, zainteresowania, historię, sport) — powrót do stanu czystej instalacji.
  Future<void> resetAllLocalData() async {
    await BackgroundService().cancelAllTasks();
    const boxNames = [
      'settings',
      'news_sources_dynamic',
      'news_categories_dynamic',
      'articles',
      'news_cache',
      'notified_ids',
      'user_tags',
      'user_interests',
      'reading_history',
      'notification_history',
      'pinned_matches',
      'pinned_match_scores',
      'sports_notified_ids',
      'match_reminders_notified',
      'daily_notification_count',
      'sports_cache',
    ];
    for (final name in boxNames) {
      try {
        if (Hive.isBoxOpen(name)) {
          await Hive.box(name).clear();
          await Hive.box(name).close();
        }
        if (!Hive.isBoxOpen(name)) {
          await Hive.deleteBoxFromDisk(name);
        }
      } catch (_) {
        // box mógł nie istnieć — pomiń
      }
    }
    await StorageService().init();
    await init();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await Hive.box(settingsBoxName).put(themeKey, mode.index);
    notifyListeners();
  }

  Future<void> setThemeVariant(AppThemeVariant variant) async {
    _themeVariant = variant;
    await Hive.box(settingsBoxName).put(themeVariantKey, variant.index);
    notifyListeners();
  }

  Future<void> toggleCategory(String id) async {
    _activeCategoryIds.contains(id) ? _activeCategoryIds.remove(id) : _activeCategoryIds.add(id);
    await Hive.box(settingsBoxName).put(activeCategoriesKey, _activeCategoryIds);
    notifyListeners();
  }

  Future<void> toggleSource(String id) async {
    _enabledSourceIds.contains(id) ? _enabledSourceIds.remove(id) : _enabledSourceIds.add(id);
    await Hive.box(settingsBoxName).put(sourcesEnabledKey, _enabledSourceIds);
    notifyListeners();
  }

  bool isSourceActive(String id) => _enabledSourceIds.contains(id);

  Future<void> _saveEnabledSources() async {
    await Hive.box(settingsBoxName).put(sourcesEnabledKey, _enabledSourceIds);
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

  Future<void> toggleShowAllSources(bool val) async {
    _showAllSources = val;
    await Hive.box(settingsBoxName).put(showAllSourcesKey, val);
    notifyListeners();
  }

  Future<void> setPreferredCity(String name, double lat, double lon) async {
    _preferredCity = name;
    _cityLatitude = lat;
    _cityLongitude = lon;
    final box = Hive.box(settingsBoxName);
    await box.put(preferredCityKey, name);
    await box.put(cityLatKey, lat);
    await box.put(cityLonKey, lon);

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

  Future<void> setReadingFontSize(int size) async {
    _readingFontSize = size;
    await Hive.box(settingsBoxName).put(readingFontSizeKey, size);
    notifyListeners();
  }

  Future<void> setReadingFont(String font) async {
    _readingFont = font;
    await Hive.box(settingsBoxName).put(readingFontKey, font);
    notifyListeners();
  }

  Future<void> setArticleListLayout(String layout) async {
    _articleListLayout = layout;
    await Hive.box(settingsBoxName).put(articleListLayoutKey, layout);
    notifyListeners();
  }

  Future<void> setImageDisplayMode(String mode) async {
    _imageDisplayMode = mode;
    await Hive.box(settingsBoxName).put(imageDisplayModeKey, mode);
    notifyListeners();
  }

  Future<void> setOpenArticlesInBrowser(bool val) async {
    _openArticlesInBrowser = val;
    await Hive.box(settingsBoxName).put(openArticlesInBrowserKey, val);
    notifyListeners();
  }

  Future<void> setShowFinished(bool val) async {
    _showFinished = val;
    await Hive.box(settingsBoxName).put(showFinishedKey, val);
    notifyListeners();
  }

  Future<void> setShowUpcoming(bool val) async {
    _showUpcoming = val;
    await Hive.box(settingsBoxName).put(showUpcomingKey, val);
    notifyListeners();
  }

  Future<void> setSportResultNotifications(bool val) async {
    _sportResultNotifications = val;
    await Hive.box(settingsBoxName).put(sportResultNotificationsKey, val);
    notifyListeners();
  }

  Future<void> setSportStartNotifications(bool val) async {
    _sportStartNotifications = val;
    await Hive.box(settingsBoxName).put(sportStartNotificationsKey, val);
    notifyListeners();
  }

  Future<void> setNotificationHours(int startHour, int endHour) async {
    _notificationStartHour = startHour;
    _notificationEndHour = endHour;
    final box = Hive.box(settingsBoxName);
    await box.put(notificationStartHourKey, startHour);
    await box.put(notificationEndHourKey, endHour);
    notifyListeners();
  }

  /// 0 = ręcznie, inaczej co [hours] godzin.
  Future<void> setRefreshFrequencyHours(int hours) async {
    _refreshFrequencyHours = hours;
    await Hive.box(settingsBoxName).put(refreshFrequencyHoursKey, hours);
    notifyListeners();
  }

  /// Częstotliwość cykli Wartownika Sowy (1 / 3 / 24 godziny).
  Future<void> setNotificationCheckFrequencyHours(int hours) async {
    _notificationCheckFrequencyHours = hours;
    await Hive.box(settingsBoxName).put(notificationCheckFrequencyHoursKey, hours);
    if (_notificationsEnabled) {
      await BackgroundService().registerPeriodicTask(frequencyHours: hours);
    }
    notifyListeners();
  }

  /// Włącza/wyłącza rodzaj alertu (ważne / nowe / podsumowanie).
  Future<void> toggleAlertType(String type, bool enabled) async {
    if (enabled) {
      if (!_alertTypes.contains(type)) _alertTypes.add(type);
    } else {
      _alertTypes.remove(type);
    }
    await Hive.box(settingsBoxName).put(alertTypesKey, _alertTypes);
    notifyListeners();
  }

  /// Odświeżanie treści wyłącznie po Wi-Fi.
  Future<void> setWifiOnlyRefresh(bool enabled) async {
    _wifiOnlyRefresh = enabled;
    await Hive.box(settingsBoxName).put(wifiOnlyRefreshKey, enabled);
    notifyListeners();
  }

  /// Po ilu dniach usuwać stare artykuły z cache (0 = nigdy).
  Future<void> setArticleRetentionDays(int days) async {
    _articleRetentionDays = days;
    await Hive.box(settingsBoxName).put(articleRetentionDaysKey, days);
    notifyListeners();
  }

  /// Domyślna kolejność artykułów: latest / unread / popular.
  Future<void> setArticleSortOrder(String order) async {
    _articleSortOrder = order;
    await Hive.box(settingsBoxName).put(articleSortOrderKey, order);
    notifyListeners();
  }

  Future<void> addExcludedWord(String word) async {
    final w = word.trim().toLowerCase();
    if (w.isEmpty || _excludedWords.length >= maxKeywords) return;
    if (_excludedWords.any((e) => e.toLowerCase() == w)) return;
    _excludedWords.add(word.trim());
    await Hive.box(settingsBoxName).put(excludedWordsKey, _excludedWords);
    notifyListeners();
  }

  Future<void> removeExcludedWord(String word) async {
    _excludedWords.remove(word);
    await Hive.box(settingsBoxName).put(excludedWordsKey, _excludedWords);
    notifyListeners();
  }

  /// Włącza/wyłącza zakres danych wysyłany do chmury.
  Future<void> toggleSyncScope(String scope, bool enabled) async {
    if (enabled) {
      if (!_syncScope.contains(scope)) _syncScope.add(scope);
    } else {
      _syncScope.remove(scope);
    }
    await Hive.box(settingsBoxName).put(syncScopeKey, _syncScope);
    notifyListeners();
  }

  /// Automatyczna synchronizacja przy otwarciu i powrocie do aplikacji.
  Future<void> setAutoSyncEnabled(bool enabled) async {
    _autoSyncEnabled = enabled;
    await Hive.box(settingsBoxName).put(autoSyncEnabledKey, enabled);
    notifyListeners();
  }

  int _hourSetting(Box settingsBox, String key, int defaultValue) {
    final val = settingsBox.get(key);
    if (val is int && val >= 0 && val < 24) return val;
    return defaultValue;
  }

  Future<void> setMainTabSlot(int slot, String categoryId) async {
    final key = slot == 1 ? mainTabSlot1Key : mainTabSlot2Key;
    if (slot == 1) {
      _mainTabSlot1 = categoryId;
    } else {
      _mainTabSlot2 = categoryId;
    }
    await Hive.box(settingsBoxName).put(key, categoryId);
    notifyListeners();
  }

  NewsCategory? getCategoryById(String id) {
    try {
      return _allCategories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Kategorie niewykorzystane w zakładkach głównych (do wyboru w slotach)
  List<NewsCategory> get availableCategoriesForSlots {
    final locked = {'all', 'api_news', _mainTabSlot1, _mainTabSlot2};
    return _allCategories.where((c) => !locked.contains(c.id)).toList();
  }

  /// Kategorie do zakładki "Tematy" (wszystkie oprócz głównych zakładek)
  Future<void> reorderTopicCategories(int oldIndex, int newIndex) async {
    final topics = topicCategories;
    if (oldIndex < 0 || oldIndex >= topics.length) return;
    if (newIndex < 0 || newIndex >= topics.length) return;
    final catId = topics[oldIndex].id;
    final targetId = topics[newIndex].id;
    final oldOrderIdx = _categoryOrder.indexOf(catId);
    final newOrderIdx = _categoryOrder.indexOf(targetId);
    if (oldOrderIdx == -1 || newOrderIdx == -1) return;
    _categoryOrder.removeAt(oldOrderIdx);
    _categoryOrder.insert(newOrderIdx, catId);
    await Hive.box(settingsBoxName).put(categoryOrderKey, _categoryOrder);
    notifyListeners();
  }

  List<NewsCategory> get _allCategoriesOrdered {
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

  List<NewsCategory> get topicCategories {
    final excluded = {'all', 'api_news', _mainTabSlot1, _mainTabSlot2};
    return _allCategoriesOrdered
        .where((c) => !excluded.contains(c.id) && _activeCategoryIds.contains(c.id))
        .toList();
  }
}
