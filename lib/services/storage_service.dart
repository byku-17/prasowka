import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/models/news_source.dart';
import 'package:prasowka/models/news_category.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String articlesBoxName = 'articles';
  static const String cacheBoxName = 'news_cache';
  static const String notifiedBoxName = 'notified_ids';

  Future<void> init() async {
    try {
      _registerAdapters();
      await _openSafe(articlesBoxName);
      await _openSafe(cacheBoxName);
      await _openSafe(notifiedBoxName);
      // Kompaktacja w tle — nie blokuj startu aplikacji.
      unawaited(_compactAll());
    } catch (e) {
      debugPrint('Sowa Storage: Krytyczny błąd inicjalizacji ($e)');
    }
  }

  /// Kompaktuje otwarte boxy (czyści fragmentację po usuniętych wpisach).
  /// Uruchamiana asynchronicznie, by nie opóźniać startu.
  Future<void> _compactAll() async {
    for (final name in [articlesBoxName, cacheBoxName, notifiedBoxName]) {
      try {
        if (Hive.isBoxOpen(name)) {
          await Hive.box(name).compact();
        }
      } catch (e) {
        debugPrint('Sowa Storage: Problem z kompaktowaniem $name ($e)');
      }
    }
  }

  /// Inicjalizacja dla izolatu tła (Workmanager). Otwiera WYŁĄCZNIE box
  /// 'notified_ids', który jest używany w tle. NIE otwiera boxów
  /// współdzielonych z UI (articles, news_cache) — unika to pól
  /// wyścigu między izolatami na tych samych plikach Hive.
  Future<void> initForBackground() async {
    try {
      _registerAdapters();
      await _openSafe(notifiedBoxName);
    } catch (e) {
      debugPrint('Sowa Storage: Krytyczny błąd inicjalizacji tła ($e)');
    }
  }

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ArticleAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(NewsSourceAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(NewsCategoryAdapter());
  }

  Future<void> _openSafe(String name) async {
    const maxRetries = 3;
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (!Hive.isBoxOpen(name)) {
          await Hive.openBox(name);
        }
        return;
      } catch (e) {
        debugPrint('Sowa Storage: Problem z boxem $name (próba ${attempt + 1}/$maxRetries): $e');
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 200 * (attempt + 1)));
        }
      }
    }
    debugPrint('Sowa Storage: Nie udało się otworzyć boxa $name po $maxRetries próbach');
  }

  bool wasNotified(String id) {
    if (!Hive.isBoxOpen(notifiedBoxName)) return false;
    final box = Hive.box(notifiedBoxName);
    return box.get(id, defaultValue: false) == true;
  }

  Future<void> markAsNotified(String id) async {
    if (!Hive.isBoxOpen(notifiedBoxName)) return;
    final box = Hive.box(notifiedBoxName);
    await box.put(id, true);
  }

  Future<void> saveCategoryCache(String categoryId, List<Article> newArticles) async {
    if (!Hive.isBoxOpen(cacheBoxName)) return;
    final box = Hive.box(cacheBoxName);
    final currentCache = getCategoryCache(categoryId);
    final Map<String, Article> uniqueArticles = {};
    for (var a in currentCache) { uniqueArticles[a.id] = a; }
    for (var a in newArticles) {
      final existing = uniqueArticles[a.id];
      if (existing != null) {
        if (existing.isRead) a.isRead = true;
        if (existing.isSaved) a.isSaved = true;
        if (existing.isLiked) a.isLiked = true;
        if (existing.isDisliked) a.isDisliked = true;
        if (existing.fullContent != null && existing.fullContent!.trim().length >= 350) a.fullContent = existing.fullContent;
        if (existing.translatedTitle != null) a.translatedTitle = existing.translatedTitle;
        if (existing.translatedDescription != null) a.translatedDescription = existing.translatedDescription;
        if (existing.translatedFullContent != null) a.translatedFullContent = existing.translatedFullContent;
        if (existing.tagIds.isNotEmpty) a.tagIds = existing.tagIds;
        a.readTimeSeconds = existing.readTimeSeconds;
      }
      uniqueArticles[a.id] = a;
    }
    final List<Article> combinedList = uniqueArticles.values.toList();
    combinedList.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    final limitedList = combinedList.take(200).toList();
    // Truncate fullContent do ~10K znaków — pełna treść jest ładowana
    // leniwie via fetchFullArticleContent. Oszczędza ~8MB przy 200 artykułach.
    for (var a in limitedList) {
      a.fullContent = _truncateContent(a.fullContent);
      a.translatedFullContent = _truncateContent(a.translatedFullContent);
    }
    await box.put(categoryId, limitedList);
    _categoryCacheMemory[categoryId] = limitedList;
  }

  /// In-memory cache per categoryId — unika deserializacji 200 artykułów
  /// z Hive przy każdym odczycie.
  final Map<String, List<Article>> _categoryCacheMemory = {};

  List<Article> getCategoryCache(String categoryId) {
    final memCached = _categoryCacheMemory[categoryId];
    if (memCached != null) return memCached;
    if (!Hive.isBoxOpen(cacheBoxName)) return [];
    final box = Hive.box(cacheBoxName);
    final cached = box.get(categoryId);
    if (cached != null) {
      final list = List<Article>.from(cached);
      _categoryCacheMemory[categoryId] = list;
      return list;
    }
    return [];
  }

  static const int _maxContentLength = 10000;

  String? _truncateContent(String? content) {
    if (content == null || content.length <= _maxContentLength) return content;
    return content.substring(0, _maxContentLength);
  }

  Future<void> clearAllCache() async {
    _categoryCacheMemory.clear();
    if (Hive.isBoxOpen(cacheBoxName)) {
      await Hive.box(cacheBoxName).clear();
    }
  }

  Future<void> toggleSaved(Article article) async {
    if (!Hive.isBoxOpen(articlesBoxName)) return;
    final box = Hive.box(articlesBoxName);
    article.isSaved = !article.isSaved;
    if (article.isSaved || article.tagIds.isNotEmpty) {
      await box.put(article.id, article);
    } else {
      await box.delete(article.id);
    }
  }

  List<Article> getSavedArticles() {
    if (!Hive.isBoxOpen(articlesBoxName)) return [];
    final box = Hive.box(articlesBoxName);
    return box.values.cast<Article>().where((a) => a.isSaved).toList();
  }

  Future<void> toggleArticleTag(Article article, String tagId) async {
    if (!Hive.isBoxOpen(articlesBoxName)) return;
    final box = Hive.box(articlesBoxName);
    if (article.tagIds.contains(tagId)) {
      article.tagIds.remove(tagId);
    } else {
      article.tagIds.add(tagId);
    }
    if (article.isSaved || article.tagIds.isNotEmpty) {
      await box.put(article.id, article);
    } else {
      await box.delete(article.id);
    }
  }

  Article? getStoredArticle(String id) {
    if (!Hive.isBoxOpen(articlesBoxName)) return null;
    final box = Hive.box(articlesBoxName);
    return box.get(id) as Article?;
  }

  Future<void> saveArticleState(Article article) async {
    if (!Hive.isBoxOpen(articlesBoxName)) return;
    final box = Hive.box(articlesBoxName);
    await box.put(article.id, article);
  }
}
