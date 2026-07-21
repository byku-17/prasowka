import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/news_category.dart';
import '../models/news_source.dart';

class SettingsProvider with ChangeNotifier {
  static const String settingsBoxName = 'settings';
  static const String themeKey = 'themeMode';
  static const String categoriesKey = 'activeCategories';
  static const String sourcesKey = 'activeSources';
  static const String teamsKey = 'favoriteTeams';

  ThemeMode _themeMode = ThemeMode.system;
  List<String> _activeCategoryIds = [];
  List<String> _activeSourceIds = [];
  List<String> _favoriteTeams = [];

  ThemeMode get themeMode => _themeMode;
  List<String> get activeCategoryIds => _activeCategoryIds;
  List<String> get activeSourceIds => _activeSourceIds;
  List<String> get favoriteTeams => _favoriteTeams;

  /// Inicjalizacja ustawień z Hive
  Future<void> init() async {
    final box = await Hive.openBox(settingsBoxName);

    // 1. Motyw
    final themeIndex = box.get(themeKey, defaultValue: ThemeMode.system.index);
    _themeMode = ThemeMode.values[themeIndex];

    // 2. Kategorie (domyślnie wszystkie)
    _activeCategoryIds = List<String>.from(box.get(
      categoriesKey,
      defaultValue: NewsCategory.defaultCategories.map((c) => c.id).toList(),
    ));

    // 3. Źródła (domyślnie wszystkie)
    _activeSourceIds = List<String>.from(box.get(
      sourcesKey,
      defaultValue: NewsSource.defaultSources.map((s) => s.id).toList(),
    ));

    // 4. Ulubione drużyny
    _favoriteTeams = List<String>.from(box.get(teamsKey, defaultValue: <String>[]));

    notifyListeners();
  }

  /// Zmiana motywu
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final box = Hive.box(settingsBoxName);
    await box.put(themeKey, mode.index);
    notifyListeners();
  }

  /// Przełączanie aktywności kategorii
  Future<void> toggleCategory(String categoryId) async {
    if (_activeCategoryIds.contains(categoryId)) {
      _activeCategoryIds.remove(categoryId);
    } else {
      _activeCategoryIds.add(categoryId);
    }
    
    final box = Hive.box(settingsBoxName);
    await box.put(categoriesKey, _activeCategoryIds);
    notifyListeners();
  }

  /// Przełączanie aktywności źródła
  Future<void> toggleSource(String sourceId) async {
    if (_activeSourceIds.contains(sourceId)) {
      _activeSourceIds.remove(sourceId);
    } else {
      _activeSourceIds.add(sourceId);
    }
    
    final box = Hive.box(settingsBoxName);
    await box.put(sourcesKey, _activeSourceIds);
    notifyListeners();
  }

  /// Zarządzanie drużynami
  Future<void> addTeam(String teamName) async {
    final name = teamName.trim();
    if (name.isEmpty || _favoriteTeams.contains(name)) return;
    _favoriteTeams.add(name);
    final box = Hive.box(settingsBoxName);
    await box.put(teamsKey, _favoriteTeams);
    notifyListeners();
  }

  Future<void> removeTeam(String teamName) async {
    _favoriteTeams.remove(teamName);
    final box = Hive.box(settingsBoxName);
    await box.put(teamsKey, _favoriteTeams);
    notifyListeners();
  }

  /// Masowe przełączanie źródeł w kategorii
  Future<void> toggleAllSourcesInCategory(String categoryId, bool enable) async {
    final categorySources = NewsSource.defaultSources
        .where((s) => s.categoryId == categoryId)
        .map((s) => s.id)
        .toList();

    if (enable) {
      for (var id in categorySources) {
        if (!_activeSourceIds.contains(id)) _activeSourceIds.add(id);
      }
    } else {
      _activeSourceIds.removeWhere((id) => categorySources.contains(id));
    }

    final box = Hive.box(settingsBoxName);
    await box.put(sourcesKey, _activeSourceIds);
    notifyListeners();
  }

  /// Przełączanie wszystkich źródeł globalnie
  Future<void> toggleAllSources(bool enable) async {
    if (enable) {
      _activeSourceIds = NewsSource.defaultSources.map((s) => s.id).toList();
    } else {
      _activeSourceIds = [];
    }

    final box = Hive.box(settingsBoxName);
    await box.put(sourcesKey, _activeSourceIds);
    notifyListeners();
  }

  /// Pomocnicze listy obiektów (filtrowane)
  List<NewsCategory> get activeCategories => NewsCategory.defaultCategories
      .where((c) => _activeCategoryIds.contains(c.id))
      .toList();

  List<NewsSource> get activeSources => NewsSource.defaultSources
      .where((s) => _activeSourceIds.contains(s.id))
      .toList();

  bool isCategoryActive(String id) => _activeCategoryIds.contains(id);
  bool isSourceActive(String id) => _activeSourceIds.contains(id);
}
