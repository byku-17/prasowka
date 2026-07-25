import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:prasowka/models/news_category.dart';
import 'package:prasowka/models/news_source.dart';
import 'package:prasowka/services/storage_service.dart';
import 'package:prasowka/services/background_service.dart';

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

  ThemeMode _themeMode = ThemeMode.system;
  List<NewsCategory> _allCategories = [];
  List<String> _activeCategoryIds = [];
  List<String> _enabledSourceIds = [];
  List<String> _favoriteTeams = [];
  List<String> _categoryOrder = [];
  List<NewsSource> _allSources = [];
  bool _onlyFavoriteTeams = true; // Domyślnie filtrujemy do zainteresowań
  bool _notificationsEnabled = false;
  bool _onboardingCompleted = false;
  bool _showSportsBar = true;
  int _lastTabIndex = 0;

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

  Future<void> init() async {
    debugPrint('Sowa Settings: Inicjalizacja V4.2...');
    
    await StorageService().init();
    final settingsBox = await Hive.openBox(settingsBoxName);

    // 1. Inicjalizacja Kategorii
    final categoriesBox = await Hive.openBox<NewsCategory>(categoriesBoxName);
    if (categoriesBox.isEmpty) {
      await categoriesBox.putAll({for (var c in NewsCategory.defaultCategories) c.id: c});
    }
    _allCategories = categoriesBox.values.toList();

    // 2. Inicjalizacja Źródeł
    final sourcesBox = await Hive.openBox<NewsSource>(sourcesBoxName);
    if (sourcesBox.isEmpty || sourcesBox.length < (NewsSource.defaultSources.length * 0.9)) {
      await resetToDefaultSources();
    } else {
      _allSources = sourcesBox.values.toList();
    }

    // 3. Ustawienia ogólne
    final themeIndex = settingsBox.get(themeKey, defaultValue: ThemeMode.system.index);
    _themeMode = ThemeMode.values[themeIndex];
    _onboardingCompleted = settingsBox.get(onboardingKey, defaultValue: false);
    _showSportsBar = settingsBox.get(sportsBarKey, defaultValue: true);
    _onlyFavoriteTeams = settingsBox.get(onlyFavoriteTeamsKey, defaultValue: true);
    _lastTabIndex = settingsBox.get(lastTabIndexKey, defaultValue: 0);

    // 4. Aktywne kategorie
    _activeCategoryIds = List<String>.from(settingsBox.get(
      activeCategoriesKey,
      defaultValue: _allCategories.map((c) => c.id).toList(),
    ));

    // 5. Włączone źródła (domyślnie te z isDefault)
    _enabledSourceIds = List<String>.from(settingsBox.get(
      sourcesEnabledKey,
      defaultValue: _allSources.where((s) => s.isDefault).map((s) => s.id).toList(),
    ));

    if (_enabledSourceIds.isEmpty && _allSources.isNotEmpty) {
      _enabledSourceIds = _allSources.where((s) => s.isDefault).map((s) => s.id).toList();
      await saveEnabledSources();
    }

    // 6. Zainteresowania (słowa kluczowe)
    _favoriteTeams = List<String>.from(settingsBox.get(teamsKey, defaultValue: <String>[]));
    
    // 7. Kolejność kategorii
    _categoryOrder = List<String>.from(settingsBox.get(
      categoryOrderKey,
      defaultValue: _allCategories.map((c) => c.id).toList(),
    ));

    // 8. Powiadomienia
    _notificationsEnabled = settingsBox.get(notificationsKey, defaultValue: false);
    await BackgroundService().init();
    if (_notificationsEnabled) {
      await BackgroundService().registerPeriodicTask();
    }

    await _ensureNewSourcesRegistered();
    notifyListeners();
    debugPrint('Sowa Settings: Gotowe (Tryb Personalizacji OK)');
  }

  /// Upewnia się, że nowe źródła (np. naTemat.pl) są obecne u starych użytkowników
  Future<void> _ensureNewSourcesRegistered() async {
    final box = await Hive.openBox<NewsSource>(sourcesBoxName);
    const newId = 'natemat_pl';
    if (!box.containsKey(newId)) {
      final source = NewsSource.defaultSources.firstWhere((s) => s.id == newId, orElse: () => NewsSource.defaultSources.first);
      await box.put(newId, source);
      _allSources = box.values.toList();
      debugPrint('Sowa Settings: Zarejestrowano nowe źródło: $newId');
    }
  }

  Future<void> toggleNotifications(bool enabled) async {
    if (enabled) {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    }
    _notificationsEnabled = enabled;
    await Hive.box(settingsBoxName).put(notificationsKey, enabled);
    if (enabled) await BackgroundService().registerPeriodicTask(); else await BackgroundService().cancelAllTasks();
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

  Future<void> reorderCategories(int old, int neu) async {
    if (neu > old) neu -= 1;
    final item = _categoryOrder.removeAt(old);
    _categoryOrder.insert(neu, item);
    await Hive.box(settingsBoxName).put(categoryOrderKey, _categoryOrder);
    notifyListeners();
  }

  /// Wszystkie kategorie (aktywne i nieaktywne) w kolejności ustawionej przez użytkownika
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

  /// Sprawdza czy kategoria o danym ID jest aktywna
  bool isCategoryActive(String id) => _activeCategoryIds.contains(id);

  /// Sprawdza czy źródło o danym ID jest włączone
  bool isSourceActive(String id) => _enabledSourceIds.contains(id);

  /// Zwraca tylko aktywne kategorie w kolejności ustawionej przez użytkownika
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

  /// Dodaje nową kategorię użytkownika (np. "AI", "Finanse")
  Future<void> addCustomCategory(String name, IconData icon) async {
    final id = 'custom_${name.toLowerCase().replaceAll(' ', '_')}';
    if (_allCategories.any((c) => c.id == id)) return;

    final newCategory = NewsCategory(
      id: id,
      name: name,
      iconCode: icon.codePoint,
      isCustom: true,
    );

    final box = Hive.box<NewsCategory>(categoriesBoxName);
    await box.put(id, newCategory);
    _allCategories = box.values.toList();
    _categoryOrder.add(id);
    await Hive.box(settingsBoxName).put(categoryOrderKey, _categoryOrder);
    _activeCategoryIds.add(id);
    await Hive.box(settingsBoxName).put(activeCategoriesKey, _activeCategoryIds);
    notifyListeners();
  }

  /// Ustawia listę aktywnych kategorii (używane przy onboardingu)
  Future<void> setSelectedCategories(List<String> ids) async {
    _activeCategoryIds = List<String>.from(ids);
    // Upewnij się, że kategoria "all" jest zawsze aktywna
    if (!_activeCategoryIds.contains('all')) {
      _activeCategoryIds.insert(0, 'all');
    }
    await Hive.box(settingsBoxName).put(activeCategoriesKey, _activeCategoryIds);
    notifyListeners();
  }

  /// Oznacza onboardig jako zakończony
  Future<void> completeOnboarding() async {
    _onboardingCompleted = true;
    await Hive.box(settingsBoxName).put(onboardingKey, true);
    notifyListeners();
  }
}
