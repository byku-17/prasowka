import 'package:hive_flutter/hive_flutter.dart';
import '../models/article.dart';

class StorageService {
  static const String articlesBoxName = 'articles';

  /// Inicjalizacja Hive i otwarcie boxa (bezpieczna)
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(ArticleAdapter().typeId)) {
      Hive.registerAdapter(ArticleAdapter());
    }
    if (!Hive.isBoxOpen(articlesBoxName)) {
      await Hive.openBox<Article>(articlesBoxName);
    }
  }

  /// Zapisuje lub usuwa artykuł z ulubionych
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
