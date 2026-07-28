import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
  final Map<String, String?> _errorMap = {};
  final Map<String, bool> _hasEverLoadedMap = {};
  
  String _lastDebugMessage = 'Czekam na akcję...';
  String? _lastTechnicalError; 
  
  List<Article> _recommendedArticles = [];
  bool _isFetchingFullContent = false;
  bool _isTranslating = false;
  NewsCategory _selectedCategory = NewsCategory.defaultCategories.first;
  
  List<String>? _lastActiveSourceIds;
  List<String>? _lastFavoriteTeams;
  final Map<String, DateTime> _lastFetchTimes = {};
  final Map<String, String> _requestIds = {};

  // Getters
  List<Article> get articles => _articlesMap[_selectedCategory.id] ?? [];
  List<Article> get recommendedArticles => _recommendedArticles;
  bool get isLoading => _loadingMap[_selectedCategory.id] ?? false;
  String? get errorMessage => _errorMap[_selectedCategory.id];
  NewsCategory get selectedCategory => _selectedCategory;
  bool get isFetchingFullContent => _isFetchingFullContent;
  bool get isTranslating => _isTranslating;
  String get lastDebugMessage => _lastDebugMessage;
  String? get lastTechnicalError => _lastTechnicalError;

  List<Article> getArticlesForCategory(String categoryId) => _articlesMap[categoryId] ?? [];
  bool isCategoryLoading(String categoryId) => _loadingMap[categoryId] ?? false;
  bool hasCategoryEverLoaded(String categoryId) => _hasEverLoadedMap[categoryId] ?? false;
  String? getCategoryError(String categoryId) => _errorMap[categoryId];

  Future<void> init() async {
    try {
      await _interestService.init();
      notifyListeners();
    } catch (e) {
      _lastTechnicalError = e.toString();
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

    final cached = _storageService.getCategoryCache(categoryId);
    if (cached.isNotEmpty && !forceRefresh) {
      _articlesMap[categoryId] = cached;
      _hasEverLoadedMap[categoryId] = true;
      _calculateRecommendations();
      final lastFetch = _lastFetchTimes[categoryId];
      if (lastFetch != null && DateTime.now().difference(lastFetch).inMinutes < 5) {
        notifyListeners();
        return;
      }
    } else if (cached.isNotEmpty) {
      _hasEverLoadedMap[categoryId] = true;
    }

    _loadingMap[categoryId] = true;
    _errorMap[categoryId] = null;
    notifyListeners();

    try {
      final List<NewsSource> baseSources = (allSources != null && allSources.isNotEmpty) 
          ? allSources 
          : NewsSource.defaultSources;
          
      List<NewsSource> sourcesToFetch;
      if (categoryId == 'all') {
        sourcesToFetch = baseSources.where((s) => NewsSource.topSourceIds.contains(s.id) || s.id.startsWith('custom_')).toList();
      } else {
        sourcesToFetch = baseSources.where((s) => s.categoryId == categoryId).toList();
      }

      final activeIds = enabledSourceIds ?? _lastActiveSourceIds;
      if (activeIds != null && activeIds.isNotEmpty) {
        final filtered = sourcesToFetch.where((s) => activeIds.contains(s.id)).toList();
        if (filtered.isNotEmpty) sourcesToFetch = filtered;
      }

      if (sourcesToFetch.isEmpty) {
        sourcesToFetch = baseSources.where((s) => s.categoryId == categoryId).toList();
        if (categoryId == 'all') sourcesToFetch = baseSources.take(30).toList();
      }

      List<Article> accumulated = [];

      for (int i = 0; i < sourcesToFetch.length; i += 10) {
        final batch = sourcesToFetch.skip(i).take(10).toList();
        final results = await Future.wait(batch.map((s) => _rssService.fetchArticles(s)));
        
        if (_requestIds[categoryId] != requestId) return;

        bool hasNew = false;
        for (var fetched in results) {
          if (fetched.isNotEmpty) {
            hasNew = true;
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
            }
            accumulated.addAll(fetched);
          }
        }
        
        if (hasNew) {
          _lastDebugMessage = 'Pobrano ${accumulated.length} newsów...';
          _hasEverLoadedMap[categoryId] = true;
          if (accumulated.length % 200 == 0) _calculateRecommendations();
          // Progressive loading — aktualizuj UI po każdym batchu
          _articlesMap[categoryId] = List.from(accumulated);
          notifyListeners();
        }
      }

      _lastFetchTimes[categoryId] = DateTime.now();
      _articlesMap[categoryId] = accumulated;
      
      if (accumulated.length > 50) {
        // Konwertuj do Map przed compute (bezpieczne dla isolate boundaries z Article/HiveObject)
        final transferList = accumulated.map((a) => a.toTransferMap()).toList();
        final mixed = await compute(_sortAndMixArticlesStatic, {
          'list': transferList,
          'teams': favoriteTeams ?? _lastFavoriteTeams,
          'categoryId': categoryId,
        });
        _articlesMap[categoryId] = mixed;
      } else {
        _sortAndMixArticlesSync(accumulated, favoriteTeams ?? _lastFavoriteTeams, categoryId);
        _articlesMap[categoryId] = accumulated;
      }
      
      _calculateRecommendations();
      await _storageService.saveCategoryCache(categoryId, accumulated);
      
      _loadingMap[categoryId] = false;
      _hasEverLoadedMap[categoryId] = true;
      notifyListeners();
    } catch (e) {
      _logError(categoryId, e);
      _hasEverLoadedMap[categoryId] = true;
      _loadingMap[categoryId] = false;
      notifyListeners();
    }
  }

  void _calculateRecommendations() {
    final allArticles = allLoadedArticles.where((a) => !a.isDisliked).toList();
    if (allArticles.isEmpty) {
      _recommendedArticles = [];
      return;
    }
    
    // Optymalizacja: pobieramy punkty tylko raz dla każdego tagu, zamiast liczyć od nowa
    final List<MapEntry<Article, double>> scored = allArticles.map((a) {
      // Jeśli mamy cachedScore, używamy go. Jeśli nie, calculateScore go ustawi.
      return MapEntry(a, a.cachedScore ?? _interestService.calculateScore(a));
    }).where((e) => e.value > 0).toList();
    
    scored.sort((a, b) => b.value.compareTo(a.value));
    _recommendedArticles = scored.map((e) => e.key).take(5).toList();
  }

  static List<Article> _sortAndMixArticlesStatic(Map<String, dynamic> params) {
    final List<Article> list = (params['list'] as List)
        .map((m) => m is Map<String, dynamic> ? Article.fromTransferMap(m) : m as Article)
        .toList();
    final List<String>? teams = params['teams'];
    final String categoryId = params['categoryId'];

    list.sort((a, b) {
      if (a.imageUrl != null && b.imageUrl == null) return -1;
      if (a.imageUrl == null && b.imageUrl != null) return 1;
      return b.publishedAt.compareTo(a.publishedAt);
    });
    
    list.removeWhere((a) => a.isDisliked);
    
    if (list.length > 5) {
      final Map<String, List<Article>> bySource = {};
      for (var a in list) { 
        bySource.putIfAbsent(a.sourceName, () => []).add(a); 
      }
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
    return list;
  }

  void _sortAndMixArticlesSync(List<Article> list, List<String>? teams, String categoryId) {
    // Reużywamy logiki statycznej dla małych list
    final result = _sortAndMixArticlesStatic({
      'list': list,
      'teams': teams,
      'categoryId': categoryId,
    });
    list.clear();
    list.addAll(result);
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
    for (var list in _articlesMap.values) { for (var a in list) { a.cachedScore = null; } }
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
    // Nie fetchuj tu — widget CategoryNewsList zrobi to przez _fetchIfNeeded z właściwymi źródłami
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

  void _logError(String categoryId, dynamic e) {
    _lastTechnicalError = e.toString();
    _errorMap[categoryId] = 'Wystąpił problem z pobieraniem danych. Spróbuj ponownie później.';
    debugPrint('Sowa NewsProvider Error [$categoryId]: $e');
  }

  List<Article> get favoriteArticles => _storageService.getFavorites();
  List<Article> get readLaterArticles => _storageService.getReadLater();
}
