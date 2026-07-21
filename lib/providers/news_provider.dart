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
  
  // Cache filtrów, aby setCategory mogło z nich korzystać
  List<String>? _lastActiveSourceIds;
  List<String>? _lastFavoriteTeams;

  // Guard dla wyścigów stanu
  String? _currentRequestId;

  List<Article> get articles => _articles;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  NewsCategory get selectedCategory => _selectedCategory;

  /// Inicjalizacja
  Future<void> init() async {
    await _storageService.init();
  }

  /// Pobiera newsy dla aktualnie wybranej kategorii z uwzględnieniem filtrów źródeł i drużyn
  Future<void> fetchNews({List<String>? activeSourceIds, List<String>? favoriteTeams}) async {
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentRequestId = requestId;
    
    // Zapisujemy filtry do cache'u, aby były dostępne przy przełączaniu zakładek
    if (activeSourceIds != null) _lastActiveSourceIds = activeSourceIds;
    if (favoriteTeams != null) _lastFavoriteTeams = favoriteTeams;

    final effectiveSources = activeSourceIds ?? _lastActiveSourceIds;
    final effectiveTeams = favoriteTeams ?? _lastFavoriteTeams;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Wybieramy źródła
      List<NewsSource> sources;
      if (_selectedCategory.id == 'all') {
        sources = NewsSource.defaultSources;
      } else {
        sources = NewsSource.defaultSources
            .where((s) => s.categoryId == _selectedCategory.id)
            .toList();
      }

      // FILTR 1: Zostawiamy tylko te, które użytkownik aktywował w ustawieniach
      if (effectiveSources != null) {
        sources = sources.where((s) => effectiveSources.contains(s.id)).toList();
      }

      if (sources.isEmpty) {
        if (_currentRequestId != requestId) return;
        _articles = [];
        _errorMessage = 'Brak aktywnych źródeł. Sprawdź ustawienia.';
      } else {
        List<Article> allArticles = [];
        
        // Pobieramy ze wszystkich źródeł równolegle
        final fetchTasks = sources.map((source) => _rssService.fetchArticles(source));
        final results = await Future.wait(fetchTasks);
        
        if (_currentRequestId != requestId) return;

        for (var fetched in results) {
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

        if (_selectedCategory.id == 'all' && allArticles.length > 100) {
          allArticles = allArticles.sublist(0, 100);
        }

        // FILTR 2: Priorytetyzacja / Filtrowanie pod kątem drużyn
        if (_selectedCategory.id == 'sport' && effectiveTeams != null && effectiveTeams.isNotEmpty) {
          final filtered = allArticles.where((article) {
            final text = '${article.title} ${article.description}'.toLowerCase();
            return effectiveTeams.any((team) => text.contains(team.toLowerCase()));
          }).toList();
          
          if (filtered.isNotEmpty) {
             final other = allArticles.where((a) => !filtered.contains(a)).toList();
             allArticles = [...filtered, ...other];
          }
        }

        _articles = allArticles;
      }
    } catch (e) {
      if (_currentRequestId != requestId) return;
      _errorMessage = 'Błąd połączenia. Sprawdź internet.';
    } finally {
      if (_currentRequestId == requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Zmienia kategorię i czyści listę przed pobraniem nowych danych (lepsze UX)
  void setCategory(NewsCategory category) {
    if (_selectedCategory.id == category.id) return;
    _selectedCategory = category;
    _articles = []; // Czyścimy stare newsy natychmiast
    fetchNews(); // Użyje zapisanych w cache filtrów
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
