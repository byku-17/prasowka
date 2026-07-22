import 'package:hive_flutter/hive_flutter.dart';
import '../models/article.dart';

class StorageService {
  static const String articlesBoxName = 'articles';
  static const String cacheBoxName = 'news_cache';

  /// Inicjalizacja Hive i otwarcie boxów
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(ArticleAdapter().typeId)) {
      Hive.registerAdapter(ArticleAdapter());
    }
    if (!Hive.isBoxOpen(articlesBoxName)) {
      await Hive.openBox<Article>(articlesBoxName);
    }
    if (!Hive.isBoxOpen(cacheBoxName)) {
      await Hive.openBox<List>(cacheBoxName); // Przechowujemy listy artykułów per kategoria
    }
  }

  /// --- CACHE NEWSÓW ---

  /// Zapisuje listę artykułów dla konkretnej kategorii do cache'u
  Future<void> saveCategoryCache(String categoryId, List<Article> articles) async {
    final box = Hive.box<List>(cacheBoxName);
    // Zapisujemy tylko top 50 artykułów per kategoria, żeby nie zapchać pamięci
    final topArticles = articles.take(50).toList();
    await box.put(categoryId, topArticles);
  }

  /// Pobiera listę artykułów z cache'u dla kategorii
  List<Article> getCategoryCache(String categoryId) {
    final box = Hive.box<List>(cacheBoxName);
    final cached = box.get(categoryId);
    if (cached != null) {
      return List<Article>.from(cached);
    }
    return [];
  }

  /// Czyści stary cache (opcjonalnie wywoływane przy starcie)
  Future<void> clearOldCache() async {
    // Hive automatycznie nadpisuje dane per klucz, więc nie musimy czyścić ręcznie 
    // chyba że chcemy skasować wszystko.
  }

  /// --- ULUBIONE I PRZECZYTAJ PÓŹNIEJ ---
  Future<void> toggleFavorite(Article article) async {
    final box = Hive.box<Article>(articlesBoxName);
    article.isFavorite = !article.isFavorite;
    
    if (article.isFavorite || article.readLater) {
      await box.put(article.id, article);
    } else {
      // Jeśli nie jest ani ulubiony, ani do przeczytania później - usuwamy z bazy
      await box.delete(article.id);
    }
  }

  /// Zapisuje lub usuwa artykuł z listy "do przeczytania"
  Future<void> toggleReadLater(Article article) async {
    final box = Hive.box<Article>(articlesBoxName);
    article.readLater = !article.readLater;
    
    if (article.isFavorite || article.readLater) {
      await box.put(article.id, article);
    } else {
      await box.delete(article.id);
    }
  }

  /// Pobiera wszystkie zapisane artykuły
  List<Article> getSavedArticles() {
    final box = Hive.box<Article>(articlesBoxName);
    return box.values.toList();
  }

  /// Pobiera tylko ulubione
  List<Article> getFavorites() {
    return getSavedArticles().where((a) => a.isFavorite).toList();
  }

  /// Pobiera tylko do przeczytania
  List<Article> getReadLater() {
    return getSavedArticles().where((a) => a.readLater).toList();
  }

  /// Sprawdza czy dany artykuł jest już w bazie (np. żeby zaznaczyć ikonkę)
  Article? getStoredArticle(String id) {
    final box = Hive.box<Article>(articlesBoxName);
    return box.get(id);
  }
}
