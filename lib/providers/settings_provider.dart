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
  
  static const String themeKey = 'themeMode';
  static const String categoriesKey = 'activeCategories';
  static const String sourcesEnabledKey = 'activeSourceIds';
  static const String teamsKey = 'favoriteTeams';
  static const String categoryOrderKey = 'categoryOrder';
  static const String notificationsKey = 'notificationsEnabled';
  static const String onboardingKey = 'onboardingCompleted';
  static const String lastTabIndexKey = 'lastTabIndex';

  ThemeMode _themeMode = ThemeMode.system;
  List<String> _activeCategoryIds = [];
  List<String> _enabledSourceIds = [];
  List<String> _favoriteTeams = [];
  List<String> _categoryOrder = [];
  List<NewsSource> _allSources = [];
  bool _notificationsEnabled = false;
  bool _onboardingCompleted = false;
  int _lastTabIndex = 0;

  ThemeMode get themeMode => _themeMode;
  List<String> get activeCategoryIds => _activeCategoryIds;
  List<String> get enabledSourceIds => _enabledSourceIds;
  List<String> get favoriteTeams => _favoriteTeams;
  List<NewsSource> get allSources => _allSources;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get onboardingCompleted => _onboardingCompleted;
  int get lastTabIndex => _lastTabIndex;

  Future<void> init() async {
    debugPrint('Sowa Settings: Inicjalizacja...');
    final settingsBox = await Hive.openBox(settingsBoxName);
    
    await StorageService().init();

    final sourcesBox = await Hive.openBox(sourcesBoxName);

    final themeIndex = settingsBox.get(themeKey, defaultValue: ThemeMode.system.index);
    _themeMode = ThemeMode.values[themeIndex];

    final expectedCount = NewsSource.defaultSources.length;
    if (sourcesBox.isEmpty || sourcesBox.length < (expectedCount * 0.9)) {
      debugPrint('Sowa Settings: Wykryto brak źródeł (${sourcesBox.length}/$expectedCount). Resetuję...');
      await resetToDefaultSources();
    } else {
      _allSources = List<NewsSource>.from(sourcesBox.values);
      debugPrint('Sowa Settings: Wczytano ${_allSources.length} źródeł.');
    }

    _activeCategoryIds = List<String>.from(settingsBox.get(
      categoriesKey,
      defaultValue: NewsCategory.defaultCategories.map((c) => c.id).toList(),
    ));

    // Włączone źródła - Domyślnie tylko Top 3 (isDefault) dla wydajności
    _enabledSourceIds = List<String>.from(settingsBox.get(
      sourcesEnabledKey,
      defaultValue: _allSources.where((s) => s.isDefault).map((s) => s.id).toList(),
    ));

    if (_enabledSourceIds.isEmpty && _allSources.isNotEmpty) {
      _enabledSourceIds = _allSources.where((s) => s.isDefault).map((s) => s.id).toList();
      await saveEnabledSources();
    }

    _favoriteTeams = List<String>.from(settingsBox.get(teamsKey, defaultValue: <String>[]));
    
    _categoryOrder = List<String>.from(settingsBox.get(
      categoryOrderKey,
      defaultValue: NewsCategory.defaultCategories.map((c) => c.id).toList(),
    ));

    _notificationsEnabled = settingsBox.get(notificationsKey, defaultValue: false);
    _onboardingCompleted = settingsBox.get(onboardingKey, defaultValue: false);
    _lastTabIndex = settingsBox.get(lastTabIndexKey, defaultValue: 0);
    
    await BackgroundService().init();
    if (_notificationsEnabled) {
      await BackgroundService().registerPeriodicTask();
    }

    notifyListeners();
    debugPrint('Sowa Settings: Gotowe.');
  }

  Future<void> toggleNotifications(bool enabled) async {
    if (enabled) {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      final bool? granted = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      
      if (granted == false) return;
    }

    _notificationsEnabled = enabled;
    final settingsBox = Hive.box(settingsBoxName);
    await settingsBox.put(notificationsKey, enabled);
    
    if (enabled) {
      await BackgroundService().registerPeriodicTask();
    } else {
      await BackgroundService().cancelAllTasks();
    }
    
    notifyListeners();
  }

  Future<void> addCustomSource(NewsSource source) async {
    final box = Hive.box(sourcesBoxName);
    await box.put(source.id, source);
    _allSources = List<NewsSource>.from(box.values);
    _enabledSourceIds.add(source.id);
    await saveEnabledSources();
    notifyListeners();
  }

  Future<void> deleteSource(String id) async {
    final box = Hive.box(sourcesBoxName);
    await box.delete(id);
    _allSources = List<NewsSource>.from(box.values);
    _enabledSourceIds.remove(id);
    await saveEnabledSources();
    notifyListeners();
  }

  Future<void> resetToDefaultSources() async {
    debugPrint('Sowa Settings: Przywracanie domyślnych 130 źródeł i czyszczenie cache...');
    final box = Hive.box(sourcesBoxName);
    await box.clear();
    
    await StorageService().clearAllCache();
    
    final Map<String, NewsSource> sourceMap = {
      for (var s in NewsSource.defaultSources) s.id: s
    };
    await box.putAll(sourceMap);
    
    _allSources = List<NewsSource>.from(box.values);
    _enabledSourceIds = _allSources.where((s) => s.isDefault).map((s) => s.id).toList();
    await saveEnabledSources();
    notifyListeners();
    debugPrint('Sowa Settings: Przywrócono ${_allSources.length} źródeł.');
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
    await Hive.box(settingsBoxName).put(categoriesKey, _activeCategoryIds);
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
    if (neu > old) neu -= 1;
    final item = _categoryOrder.removeAt(old);
    _categoryOrder.insert(neu, item);
    await Hive.box(settingsBoxName).put(categoryOrderKey, _categoryOrder);
    notifyListeners();
  }

  Future<void> addTeam(String t) async {
    if (t.trim().isEmpty || _favoriteTeams.contains(t.trim())) return;
    _favoriteTeams.add(t.trim());
    await Hive.box(settingsBoxName).put(teamsKey, _favoriteTeams);
    notifyListeners();
  }

  Future<void> removeTeam(String t) async {
    _favoriteTeams.remove(t);
    await Hive.box(settingsBoxName).put(teamsKey, _favoriteTeams);
    notifyListeners();
  }

  List<NewsCategory> get activeCategories {
    final all = NewsCategory.defaultCategories;
    List<NewsCategory> ordered = [];
    for (var id in _categoryOrder) {
      final f = all.where((c) => c.id == id).toList();
      if (f.isNotEmpty) ordered.add(f.first);
    }
    for (var c in all) { if (!ordered.any((o) => o.id == c.id)) ordered.add(c); }
    return ordered.where((c) => _activeCategoryIds.contains(c.id)).toList();
  }

  List<NewsCategory> get allCategoriesOrdered {
    final all = NewsCategory.defaultCategories;
    List<NewsCategory> ordered = [];
    for (var id in _categoryOrder) {
      final f = all.where((c) => c.id == id).toList();
      if (f.isNotEmpty) ordered.add(f.first);
    }
    for (var c in all) { if (!ordered.any((o) => o.id == c.id)) ordered.add(c); }
    return ordered;
  }

  bool isCategoryActive(String id) => _activeCategoryIds.contains(id);
  bool isSourceActive(String id) => _enabledSourceIds.contains(id);

  /// Zapisuje ostatnio otwartą zakładkę
  Future<void> setLastTabIndex(int index) async {
    _lastTabIndex = index;
    await Hive.box(settingsBoxName).put(lastTabIndexKey, index);
    // Nie wywołujemy notifyListeners, aby uniknąć zbędnych odświeżeń UI przy zmianie zakładki
  }

  /// Markuje onboarding jako zakończony
  Future<void> completeOnboarding() async {
    _onboardingCompleted = true;
    await Hive.box(settingsBoxName).put(onboardingKey, true);
    notifyListeners();
  }
}
