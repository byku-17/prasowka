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
  bool _isBackgroundLoading = false; // Nowa flaga dla ładowania w tle
  String? _errorMessage;
  NewsCategory _selectedCategory = NewsCategory.defaultCategories.first;
  
  // Cache filtrów
  List<String>? _lastActiveSourceIds;
  List<String>? _lastFavoriteTeams;

  // Guard dla wyścigów stanu
  String? _currentRequestId;

  List<Article> get articles => _articles;
  bool get isLoading => _isLoading;
  bool get isBackgroundLoading => _isBackgroundLoading;
  String? get errorMessage => _errorMessage;
  NewsCategory get selectedCategory => _selectedCategory;

  /// Inicjalizacja
  Future<void> init() async {
    await _storageService.init();
  }

  /// Pobiera newsy: najpierw z Cache (Instant UI), potem z sieci (Background Update)
  Future<void> fetchNews({List<String>? activeSourceIds, List<String>? favoriteTeams}) async {
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    _currentRequestId = requestId;
    
    // Zapisujemy filtry do cache'u
    if (activeSourceIds != null) _lastActiveSourceIds = activeSourceIds;
    if (favoriteTeams != null) _lastFavoriteTeams = favoriteTeams;

    final effectiveSources = activeSourceIds ?? _lastActiveSourceIds;
    final effectiveTeams = favoriteTeams ?? _lastFavoriteTeams;

    // 1. ŁADOWANIE Z CACHE (Natychmiastowe)
    final cached = _storageService.getCategoryCache(_selectedCategory.id);
    if (cached.isNotEmpty) {
      _articles = cached;
      _isLoading = false;
      _isBackgroundLoading = true;
      notifyListeners();
    } else {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

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

      if (effectiveSources != null) {
        sources = sources.where((s) => effectiveSources.contains(s.id)).toList();
      }

      if (sources.isEmpty) {
        if (_currentRequestId != requestId) return;
        _isLoading = false;
        _isBackgroundLoading = false;
        if (cached.isEmpty) _articles = [];
        _errorMessage = 'Brak aktywnych źródeł.';
        notifyListeners();
        return;
      }

      // 2. ŁADOWANIE Z SIECI (Paczki/Batching po 10 źródeł)
      List<Article> allArticles = [];
      const int batchSize = 10;
      
      for (int i = 0; i < sources.length; i += batchSize) {
        final batch = sources.skip(i).take(batchSize).toList();
        final fetchTasks = batch.map((source) => _rssService.fetchArticles(source));
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
      }
      
      allArticles.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

      if (_selectedCategory.id == 'all' && allArticles.length > 100) {
        allArticles = allArticles.sublist(0, 100);
      }

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

      if (_currentRequestId != requestId) return;

      // 3. ZAPIS DO CACHE I AKTUALIZACJA UI
      _articles = allArticles;
      await _storageService.saveCategoryCache(_selectedCategory.id, allArticles);
      
      _isLoading = false;
      _isBackgroundLoading = false;
      _errorMessage = null;
      notifyListeners();

    } catch (e) {
      if (_currentRequestId != requestId) return;
      _isLoading = false;
      _isBackgroundLoading = false;
      if (_articles.isEmpty) _errorMessage = 'Błąd połączenia.';
      notifyListeners();
    }
  }

  /// Zmienia kategorię i korzysta z cache
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
