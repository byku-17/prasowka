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
    } catch (e) {
      debugPrint('Sowa Storage: Krytyczny błąd inicjalizacji ($e)');
    }
  }

  void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ArticleAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(NewsSourceAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(NewsCategoryAdapter());
  }

  Future<void> _openSafe(String name) async {
    try {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name);
      }
    } catch (e) {
      debugPrint('Sowa Storage: Problem z boxem $name ($e). Próba naprawy...');
      try {
        await Hive.deleteBoxFromDisk(name);
        await Hive.openBox(name);
        debugPrint('Sowa Storage: Box $name został usunięty i odtworzony.');
      } catch (e2) {
        debugPrint('Sowa Storage: Nie udało się odzyskać boxa $name ($e2)');
      }
    }
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
    for (var a in newArticles) { uniqueArticles[a.id] = a; }
    final List<Article> combinedList = uniqueArticles.values.toList();
    combinedList.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    final limitedList = combinedList.take(200).toList();
    await box.put(categoryId, limitedList);
  }

  List<Article> getCategoryCache(String categoryId) {
    if (!Hive.isBoxOpen(cacheBoxName)) return [];
    final box = Hive.box(cacheBoxName);
    final cached = box.get(categoryId);
    if (cached != null) {
      return List<Article>.from(cached);
    }
    return [];
  }

  Future<void> clearAllCache() async {
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

  List<Article> getArticlesWithTag(String tagId) =>
      getSavedArticles().where((a) => a.tagIds.contains(tagId)).toList();

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
}
