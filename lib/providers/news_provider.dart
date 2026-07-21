import 'package:flutter/material.dart';
import '../models/article.dart';
import '../models/news_category.dart';
import '../models/news_source.dart';
import '../services/rss_service.dart';
import '../services/storage_service.dart';

class NewsProvider with ChangeNotifier {
  final RssService _rssService = RssService();
  final StorageService _storageService = StorageService();

  List<Article> _articles = [];
  bool _isLoading = false;
  String? _errorMessage;
  NewsCategory _selectedCategory = NewsCategory.defaultCategories.first;

  List<Article> get articles => _articles;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  NewsCategory get selectedCategory => _selectedCategory;

  /// Inicjalizacja (pobranie zapisanych artykułów)
  Future<void> init() async {
    await _storageService.init();
    notifyListeners();
  }

  /// Pobiera newsy dla aktualnie wybranej kategorii
  Future<void> fetchNews() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final sources = NewsSource.defaultSources
          .where((s) => s.categoryId == _selectedCategory.id)
          .toList();

      if (sources.isEmpty) {
        _articles = [];
        _errorMessage = 'Brak źródeł dla tej kategorii.';
      } else {
        List<Article> allArticles = [];
        for (var source in sources) {
          final fetched = await _rssService.fetchArticles(source);
          
          // Dla każdego pobranego artykułu sprawdzamy, czy mamy go już w bazie (np. jako ulubiony)
          for (var article in fetched) {
            final stored = _storageService.getStoredArticle(article.id);
            if (stored != null) {
              article.isFavorite = stored.isFavorite;
              article.readLater = stored.readLater;
            }
          }
          
          allArticles.addAll(fetched);
        }
        
        allArticles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
        _articles = allArticles;
      }
    } catch (e) {
      _errorMessage = 'Nie udało się pobrać wiadomości: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Zmienia kategorię i pobiera nowe dane
  void setCategory(NewsCategory category) {
    if (_selectedCategory.id == category.id) return;
    _selectedCategory = category;
    fetchNews();
  }

  /// Obsługa ulubionych
  Future<void> toggleFavorite(Article article) async {
    await _storageService.toggleFavorite(article);
    notifyListeners();
  }

  /// Obsługa "przeczytaj później"
  Future<void> toggleReadLater(Article article) async {
    await _storageService.toggleReadLater(article);
    notifyListeners();
  }

  /// Pobiera listę zapisanych artykułów
  List<Article> get favoriteArticles => _storageService.getFavorites();
  List<Article> get readLaterArticles => _storageService.getReadLater();
}
