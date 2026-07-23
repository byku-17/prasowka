import 'package:flutter/material.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/models/news_category.dart';
import 'package:prasowka/models/news_source.dart';
import 'package:prasowka/services/rss_service.dart';
import 'package:prasowka/services/storage_service.dart';
import 'package:prasowka/services/reader_service.dart';
import 'package:prasowka/services/user_interest_service.dart';
import 'package:prasowka/services/translation_service.dart';

class NewsProvider with ChangeNotifier {
  final RssService _rssService = RssService();
  final StorageService _storageService = StorageService();
  final ReaderService _readerService = ReaderService();
  final UserInterestService _interestService = UserInterestService();
  final TranslationService _translationService = TranslationService();

  final Map<String, List<Article>> _articlesMap = {};
  final Map<String, bool> _loadingMap = {};
  final Map<String, bool> _bgLoadingMap = {};
  final Map<String, String?> _errorMap = {};
  
  String _lastDebugMessage = 'Czekam na akcję...';
  String? _lastTechnicalError; 
  int _lastSuccessCount = 0;
  int _lastSourceCount = 0;
  
  List<Article> _recommendedArticles = [];
  bool _isFetchingFullContent = false;
  bool _isTranslating = false;
  NewsCategory _selectedCategory = NewsCategory.defaultCategories.first;
  
  List<String>? _lastActiveSourceIds;
  List<String>? _lastFavoriteTeams;
  final Map<String, DateTime> _lastFetchTimes = {};
  final Map<String, String> _requestIds = {};
  final Map<String, bool> _hasEverLoadedMap = {};

  // Gettery
  List<Article> get articles => _articlesMap[_selectedCategory.id] ?? [];
  List<Article> get recommendedArticles => _recommendedArticles;
  bool get isLoading => _loadingMap[_selectedCategory.id] ?? false;
  bool get isBackgroundLoading => _bgLoadingMap[_selectedCategory.id] ?? false;
  String? get errorMessage => _errorMap[_selectedCategory.id];
  NewsCategory get selectedCategory => _selectedCategory;
  bool get isFetchingFullContent => _isFetchingFullContent;
  bool get isTranslating => _isTranslating;
  String get lastDebugMessage => _lastDebugMessage;
  String? get lastTechnicalError => _lastTechnicalError;
  int get lastSuccessCount => _lastSuccessCount;
  int get lastSourceCount => _lastSourceCount;

  List<Article> getArticlesForCategory(String categoryId) => _articlesMap[categoryId] ?? [];
  bool isCategoryLoading(String categoryId) => _loadingMap[categoryId] ?? false;
  bool isCategoryBgLoading(String categoryId) => _bgLoadingMap[categoryId] ?? false;
  bool hasCategoryEverLoaded(String categoryId) => _hasEverLoadedMap[categoryId] ?? false;
  String? getCategoryError(String categoryId) => _errorMap[categoryId];

  Future<void> init() async {
    try {
      debugPrint('Sowa NewsProvider: Inicjalizacja...');
      await _storageService.init();
      await _interestService.init();
      _lastDebugMessage = 'System gotowy.';
      notifyListeners();
    } catch (e) {
      _lastDebugMessage = 'Błąd inicjalizacji bazy.';
      _lastTechnicalError = 'Błąd: $e';
      notifyListeners();
    }
  }

  Future<void> fetchNews({
    NewsCategory? category,
    List<NewsSource>? allSources,
    List<String>? enabledSourceIds,
    List<String>? favoriteTeams,
    bool forceRefresh = false,
  }) async {
    final targetCategory = category ?? _selectedCategory;
    final categoryId = targetCategory.id;
    
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    _requestIds[categoryId] = requestId;

    if (enabledSourceIds != null) _lastActiveSourceIds = enabledSourceIds;
    if (favoriteTeams != null) _lastFavoriteTeams = favoriteTeams;

    // 1. ŁADOWANIE Z CACHE
    final cached = _storageService.getCategoryCache(categoryId);
    
    if (cached.isNotEmpty) {
      _articlesMap[categoryId] = cached;
      _loadingMap[categoryId] = false;
      _bgLoadingMap[categoryId] = true;
      _hasEverLoadedMap[categoryId] = true;
      _calculateRecommendations();
      notifyListeners();
    } else {
      _loadingMap[categoryId] = true;
      _hasEverLoadedMap[categoryId] = false;
      _errorMap[categoryId] = null;
      _lastTechnicalError = null;
      notifyListeners();
    }

    if (cached.isNotEmpty && !forceRefresh) {
      final lastFetch = _lastFetchTimes[categoryId];
      if (lastFetch != null && DateTime.now().difference(lastFetch).inMinutes < 5) {
        _bgLoadingMap[categoryId] = false;
        notifyListeners();
        return;
      }
    }

    try {
      // 2. WYBÓR ŹRÓDEŁ
      List<NewsSource> sourcesToFetch = [];
      final List<NewsSource> baseSources = (allSources != null && allSources.isNotEmpty) 
          ? allSources 
          : NewsSource.defaultSources;

      if (categoryId == 'all') {
        const topIds = ['rmf24_polska', 'tvn24_najwazniejsze', 'onet_wiadomosci', 'bbc_world', 'nyt_world', 'money_pl', 'techcrunch', 'tvp_sport', 'probasket'];
        sourcesToFetch = baseSources.where((s) => topIds.contains(s.id) || s.id.startsWith('custom_')).toList();
      } else {
        sourcesToFetch = baseSources.where((s) => s.categoryId == categoryId).toList();
      }

      final activeIds = enabledSourceIds ?? _lastActiveSourceIds;
      if (activeIds != null && activeIds.isNotEmpty) {
        final filtered = sourcesToFetch.where((s) => activeIds.contains(s.id)).toList();
        if (filtered.isNotEmpty) sourcesToFetch = filtered;
      }

      if (sourcesToFetch.isEmpty) {
        final staticSources = NewsSource.defaultSources;
        sourcesToFetch = staticSources.where((s) => s.categoryId == categoryId).toList();
        if (categoryId == 'all') sourcesToFetch = staticSources.take(30).toList();
      }

      _lastSourceCount = sourcesToFetch.length;
      _lastDebugMessage = 'Łączenie...';
      notifyListeners();

      // 3. POBIERANIE STRUMIENIOWE
      final Map<String, Article> accumulatedMap = {};
      _lastSuccessCount = 0;
      
      for (int i = 0; i < sourcesToFetch.length; i += 10) {
        final batch = sourcesToFetch.skip(i).take(10).toList();
        final results = await Future.wait(batch.map((s) => _rssService.fetchArticles(s)));
        
        if (_requestIds[categoryId] != requestId) return;

        bool hasNewArticles = false;
        for (var fetched in results) {
          if (fetched.isNotEmpty) {
            _lastSuccessCount++;
            hasNewArticles = true;
            for (var article in fetched) {
              final stored = _storageService.getStoredArticle(article.id);
              if (stored != null) {
                article.isFavorite = stored.isFavorite;
                article.readLater = stored.readLater;
                article.isLiked = stored.isLiked;
                article.isDisliked = stored.isDisliked;
                article.fullContent = stored.fullContent;
              }
              _interestService.calculateScore(article);
              accumulatedMap[article.id] = article;
            }
          }
        }
        
        if (hasNewArticles) {
          final isCurrent = categoryId == _selectedCategory.id;
          if (isCurrent || accumulatedMap.length % 50 == 0) {
            _lastDebugMessage = 'Pobrano ${accumulatedMap.length} artykułów...';
            final currentList = accumulatedMap.values.toList();
            _sortAndMixArticlesSync(currentList, favoriteTeams ?? _lastFavoriteTeams, categoryId);
            _articlesMap[categoryId] = currentList;
            _hasEverLoadedMap[categoryId] = true;
            if (accumulatedMap.length % 100 == 0) _calculateRecommendations();
            notifyListeners();
          }
        }
      }
      
      if (_requestIds[categoryId] != requestId) return;

      // 4. FINALIZACJA
      final finalArticles = accumulatedMap.values.toList();
      _lastFetchTimes[categoryId] = DateTime.now();
      _sortAndMixArticlesSync(finalArticles, favoriteTeams ?? _lastFavoriteTeams, categoryId);
      _articlesMap[categoryId] = finalArticles;
      _calculateRecommendations();
      await _storageService.saveCategoryCache(categoryId, finalArticles);
      
      _loadingMap[categoryId] = false;
      _bgLoadingMap[categoryId] = false;
      _hasEverLoadedMap[categoryId] = true;
      _lastDebugMessage = 'Sukces! (${finalArticles.length})';
      notifyListeners();

    } catch (e) {
      _lastTechnicalError = e.toString();
      _hasEverLoadedMap[categoryId] = true; 
      if (_requestIds[categoryId] != requestId) return;
      _loadingMap[categoryId] = false;
      _bgLoadingMap[categoryId] = false;
      notifyListeners();
    }
  }

  void _calculateRecommendations() {
    final allArticlesList = allLoadedArticles.where((a) => !a.isDisliked).toList();
    if (allArticlesList.isEmpty) return;
    
    final List<MapEntry<Article, double>> scored = allArticlesList
        .map((a) => MapEntry(a, _interestService.calculateScore(a)))
        .where((e) => e.value > 0)
        .toList();
        
    scored.sort((a, b) => b.value.compareTo(a.value));
    _recommendedArticles = scored.map((e) => e.key).take(5).toList();
  }

  void _sortAndMixArticlesSync(List<Article> list, List<String>? teams, String categoryId) {
    list.sort((a, b) {
      if (a.imageUrl != null && b.imageUrl == null) return -1;
      if (a.imageUrl == null && b.imageUrl != null) return 1;
      return b.publishedAt.compareTo(a.publishedAt);
    });

    list.removeWhere((a) => a.isDisliked);

    if (list.length > 5) {
      final Map<String, List<Article>> bySource = {};
      for (var a in list) { bySource.putIfAbsent(a.sourceName, () => []).add(a); }
      final List<Article> mixed = [];
      bool added = true;
      while (added) {
        added = false;
        for (var src in bySource.keys) { 
          if (bySource[src]!.isNotEmpty) { 
            mixed.add(bySource[src]!.removeAt(0)); 
            added = true; 
          } 
        }
      }
      list.clear();
      list.addAll(mixed);
    }

    if (categoryId == 'all' && list.length > 100) list.removeRange(100, list.length);

    if (categoryId == 'sport' && teams != null && teams.isNotEmpty) {
      final filtered = list.where((a) {
        final text = '${a.title} ${a.description}'.toLowerCase();
        return teams.any((t) => text.contains(t.toLowerCase()));
      }).toList();
      if (filtered.isNotEmpty) {
         final other = list.where((a) => !filtered.contains(a)).toList();
         list.clear();
         list.addAll([...filtered, ...other]);
      }
    }
  }

  Future<void> toggleLike(Article article) async {
    article.isLiked = !article.isLiked;
    if (article.isLiked) article.isDisliked = false;
    await _interestService.processInteraction(article, article.isLiked ? 1.0 : -1.0);
    _clearCachedScores();
    await _saveArticleState(article);
    _calculateRecommendations();
    notifyListeners();
  }

  Future<void> toggleDislike(Article article) async {
    article.isDisliked = !article.isDisliked;
    if (article.isDisliked) article.isLiked = false;
    await _interestService.processInteraction(article, article.isDisliked ? -2.0 : 2.0);
    _clearCachedScores();
    await _saveArticleState(article);
    for (var list in _articlesMap.values) { list.removeWhere((a) => a.id == article.id); }
    _calculateRecommendations();
    notifyListeners();
  }

  Future<void> toggleFavorite(Article article) async {
    await _storageService.toggleFavorite(article);
    await _interestService.processInteraction(article, article.isFavorite ? 2.0 : -2.0);
    _clearCachedScores();
    _calculateRecommendations();
    notifyListeners();
  }

  Future<void> toggleReadLater(Article article) async {
    await _storageService.toggleReadLater(article);
    notifyListeners();
  }

  void _clearCachedScores() {
    for (var list in _articlesMap.values) {
      for (var a in list) { a.cachedScore = null; }
    }
  }

  Future<void> _saveArticleState(Article article) async {
    final stored = _storageService.getStoredArticle(article.id);
    if (stored != null) {
      stored.isLiked = article.isLiked;
      stored.isDisliked = article.isDisliked;
      await stored.save();
    }
  }

  void setCategory(NewsCategory category) {
    if (_selectedCategory.id == category.id) return;
    _selectedCategory = category;
    notifyListeners();
    fetchNews(); 
  }

  Future<void> fetchFullArticleContent(Article article) async {
    if (article.fullContent != null) return;
    _isFetchingFullContent = true;
    notifyListeners();
    try {
      final full = await _readerService.extractFullContent(article.url);
      if (full != null) {
        article.fullContent = full;
        final s = _storageService.getStoredArticle(article.id);
        if (s != null) { s.fullContent = full; await s.save(); }
        if (article.translatedTitle != null) {
          await translateArticle(article);
        } else {
          await _storageService.saveCategoryCache(_selectedCategory.id, articles);
        }
      }
    } finally {
      _isFetchingFullContent = false;
      notifyListeners();
    }
  }

  Future<void> translateArticle(Article article) async {
    bool needsTitle = article.translatedTitle == null;
    bool needsDesc = article.translatedDescription == null;
    bool needsFull = article.fullContent != null && article.translatedFullContent == null;
    if (!needsTitle && !needsDesc && !needsFull) return;

    _isTranslating = true;
    notifyListeners();
    try {
      if (needsTitle) {
        final tTitle = await _translationService.translate(article.title);
        if (tTitle != null) article.translatedTitle = tTitle;
      }
      if (needsDesc) {
        final tDesc = await _translationService.translate(article.description);
        if (tDesc != null) article.translatedDescription = tDesc;
      }
      if (needsFull) {
        final tFull = await _translationService.translate(article.fullContent!);
        if (tFull != null) article.translatedFullContent = tFull;
      }

      final stored = _storageService.getStoredArticle(article.id);
      if (stored != null) {
        stored.translatedTitle = article.translatedTitle;
        stored.translatedDescription = article.translatedDescription;
        stored.translatedFullContent = article.translatedFullContent;
        await stored.save();
      }
      await _storageService.saveCategoryCache(_selectedCategory.id, articles);
    } finally {
      _isTranslating = false;
      notifyListeners();
    }
  }

  bool isArticlePolish(Article article) => _translationService.isProbablyPolish(article.title);

  List<Article> get allLoadedArticles {
    final Map<String, Article> unique = {};
    for (var list in _articlesMap.values) { for (var a in list) { unique[a.id] = a; } }
    return unique.values.toList();
  }

  List<Article> get favoriteArticles => _storageService.getFavorites();
  List<Article> get readLaterArticles => _storageService.getReadLater();
}
