import 'package:flutter/foundation.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/models/news_category.dart';
import 'package:prasowka/models/news_source.dart';
import 'package:prasowka/services/rss_service.dart';
import 'package:prasowka/services/storage_service.dart';
import 'package:prasowka/services/reader_service.dart';
import 'package:prasowka/services/user_interest_service.dart';
import 'package:prasowka/services/translation_service.dart';
import 'package:prasowka/services/news_api_service.dart';

class NewsProvider with ChangeNotifier {
  final RssService _rssService = RssService();
  final StorageService _storageService = StorageService();
  final ReaderService _readerService = ReaderService();
  final UserInterestService _interestService = UserInterestService();
  final TranslationService _translationService = TranslationService();
  final NewsApiService _newsApiService = NewsApiService();

  final Map<String, List<Article>> _articlesMap = {};
  final Map<String, bool> _loadingMap = {};
  final Map<String, String?> _errorMap = {};
  final Map<String, bool> _hasEverLoadedMap = {};
  
  List<Article> _recommendedArticles = [];
  final Set<String> _fetchFailedIds = {};
  bool _isFetchingFullContent = false;
  bool _isTranslating = false;
  NewsCategory _selectedCategory = NewsCategory.defaultCategories.first;
  
  List<String>? _lastActiveSourceIds;
  List<String>? _lastKeywords;
  final Map<String, DateTime> _lastFetchTimes = {};
  final Map<String, String> _requestIds = {};

  List<Article> get articles => _articlesMap[_selectedCategory.id] ?? [];
  List<Article> get recommendedArticles => _recommendedArticles;
  bool get isLoading => _loadingMap[_selectedCategory.id] ?? false;
  String? get errorMessage => _errorMap[_selectedCategory.id];
  NewsCategory get selectedCategory => _selectedCategory;
  bool get isFetchingFullContent => _isFetchingFullContent;
  bool get isTranslating => _isTranslating;
  Set<String> get fetchFailedIds => _fetchFailedIds;

  List<Article> getArticlesForCategory(String categoryId) => _articlesMap[categoryId] ?? [];
  bool isCategoryLoading(String categoryId) => _loadingMap[categoryId] ?? false;
  bool hasCategoryEverLoaded(String categoryId) => _hasEverLoadedMap[categoryId] ?? false;
  String? getCategoryError(String categoryId) => _errorMap[categoryId];

  Future<void> init() async {
    try {
      await _interestService.init();
      notifyListeners();
    } catch (e) {
      notifyListeners();
    }
  }

  Future<void> fetchNews({
    NewsCategory? category,
    List<NewsSource>? allSources,
    List<String>? enabledSourceIds,
    List<String>? keywords,
    bool forceRefresh = false,
  }) async {
    final targetCategory = category ?? _selectedCategory;
    final categoryId = targetCategory.id;
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    _requestIds[categoryId] = requestId;
    
    if (enabledSourceIds != null) _lastActiveSourceIds = enabledSourceIds;
    if (keywords != null) _lastKeywords = keywords;

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
      if (categoryId == 'api_news') {
        final articles = await _newsApiService.fetchArticles();
        if (_requestIds[categoryId] != requestId) return;
        for (var article in articles) {
          final stored = _storageService.getStoredArticle(article.id);
          if (stored != null) {
            article.isSaved = stored.isSaved;
            article.isLiked = stored.isLiked;
            article.isDisliked = stored.isDisliked;
            article.fullContent = stored.fullContent;
            article.tagIds = stored.tagIds;
          }
          _interestService.calculateScore(article);
        }
        _articlesMap[categoryId] = articles;
        _lastFetchTimes[categoryId] = DateTime.now();
        _hasEverLoadedMap[categoryId] = true;
        _calculateRecommendations();
        await _storageService.saveCategoryCache(categoryId, articles);
        _loadingMap[categoryId] = false;
        notifyListeners();
        return;
      }

      final List<NewsSource> baseSources = (allSources != null && allSources.isNotEmpty) 
          ? allSources 
          : NewsSource.defaultSources;
          
      List<NewsSource> sourcesToFetch;
      if (categoryId == 'all') {
        sourcesToFetch = baseSources.where((s) => NewsSource.topSourceIds.contains(s.id) || s.id.startsWith('custom_')).toList();
      } else if (categoryId == 'warsaw') {
        sourcesToFetch = baseSources;
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
        final results = await Future.wait(
          batch.map((s) async {
            try {
              return await _rssService.fetchArticles(s);
            } catch (e) {
              debugPrint('Sowa: Błąd źródła ${s.name}: $e');
              return <Article>[];
            }
          }),
        );
        
        if (_requestIds[categoryId] != requestId) return;

        bool hasNew = false;
        for (var fetched in results) {
          if (fetched.isNotEmpty) {
            hasNew = true;
            for (var article in fetched) {
              final stored = _storageService.getStoredArticle(article.id);
              if (stored != null) {
                article.isSaved = stored.isSaved;
                article.isLiked = stored.isLiked;
                article.isDisliked = stored.isDisliked;
                article.fullContent = stored.fullContent;
                article.tagIds = stored.tagIds;
              }
              _interestService.calculateScore(article);
            }
            accumulated.addAll(fetched);
          }
        }
        
        if (hasNew) {
          _hasEverLoadedMap[categoryId] = true;
          if (accumulated.length % 200 == 0) _calculateRecommendations();
          _articlesMap[categoryId] = List.from(accumulated);
          notifyListeners();
        }
      }

      _lastFetchTimes[categoryId] = DateTime.now();
      _articlesMap[categoryId] = accumulated;
      
      List<Article> finalList;
      if (accumulated.length > 50) {
        final transferList = accumulated.map((a) => a.toTransferMap()).toList();
        final mixed = await compute(_sortAndMixArticlesStatic, {
          'list': transferList,
          'teams': keywords ?? _lastKeywords,
          'categoryId': categoryId,
          'shuffle': forceRefresh,
        });
        _articlesMap[categoryId] = mixed;
        finalList = mixed;
      } else {
        _sortAndMixArticlesSync(accumulated, keywords ?? _lastKeywords, categoryId, shuffle: forceRefresh);
        _articlesMap[categoryId] = accumulated;
        finalList = accumulated;
      }
      
      _calculateRecommendations();
      await _storageService.saveCategoryCache(categoryId, finalList);
      
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

  List<Article> getRecommendedFrom(List<Article> candidates) {
    final filtered = candidates.where((a) => !a.isDisliked).toList();
    if (filtered.isEmpty) return [];
    
    final List<MapEntry<Article, double>> scored = filtered.map((a) {
      final base = a.cachedScore ?? _interestService.calculateScore(a);
      final withImage = base > 0 && a.imageUrl != null ? base * 1.5 : base;
      return MapEntry(a, withImage);
    }).where((e) => e.value > 0).toList();
    
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).take(3).toList();
  }

  void _calculateRecommendations() {
    final allArticles = allLoadedArticles.where((a) => !a.isDisliked).toList();
    if (allArticles.isEmpty) {
      _recommendedArticles = [];
      return;
    }
    
    final List<MapEntry<Article, double>> scored = allArticles.map((a) {
      final base = a.cachedScore ?? _interestService.calculateScore(a);
      final withImage = base > 0 && a.imageUrl != null ? base * 1.5 : base;
      return MapEntry(a, withImage);
    }).where((e) => e.value > 0).toList();
    
    scored.sort((a, b) => b.value.compareTo(a.value));
    _recommendedArticles = scored.map((e) => e.key).take(3).toList();
  }

  static List<Article> _sortAndMixArticlesStatic(Map<String, dynamic> params) {
    final List<Article> list = (params['list'] as List)
        .map((m) => m is Map<String, dynamic> ? Article.fromTransferMap(m) : m as Article)
        .toList();
    final List<String>? teams = params['teams'];
    final String categoryId = params['categoryId'];
    final bool shuffle = params['shuffle'] == true;

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

    if (shuffle && list.length > 10) {
      final rng = DateTime.now().millisecondsSinceEpoch;
      for (int i = list.length - 1; i > 0; i--) {
        final j = (rng ^ (i * 2654435761)) % (i + 1);
        final temp = list[i];
        list[i] = list[j];
        list[j] = temp;
      }
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

    final readArticles = list.where((a) => a.isRead).toList();
    final unreadArticles = list.where((a) => !a.isRead).toList();
    list.clear();
    list.addAll([...unreadArticles, ...readArticles]);

    return list;
  }

  void _sortAndMixArticlesSync(List<Article> list, List<String>? teams, String categoryId, {bool shuffle = false}) {
    final result = _sortAndMixArticlesStatic({
      'list': list,
      'teams': teams,
      'categoryId': categoryId,
      'shuffle': shuffle,
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

  void markArticleRead(Article article) {
    if (article.isRead) return;
    article.isRead = true;
    final s = _storageService.getStoredArticle(article.id);
    if (s != null) {
      s.isRead = true;
      s.readTimeSeconds = article.readTimeSeconds;
      s.save();
    }
    notifyListeners();
  }

  Future<void> toggleSaved(Article article) async {
    await _storageService.toggleSaved(article);
    if (article.isSaved) {
      await _interestService.processInteraction(article, 2.0);
      if (article.tagIds.isEmpty) {
        await _storageService.toggleArticleTag(article, 'to_read');
      }
    } else {
      await _interestService.processInteraction(article, -2.0);
    }
    _clearCachedScores();
    _calculateRecommendations();
    _invalidateSavedCache();
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
  }

  Future<void> fetchFullArticleContent(Article article) async {
    if (RssService.isGoogleNewsUrl(article.url)) return;
    _isFetchingFullContent = true;
    _fetchFailedIds.remove(article.id);
    notifyListeners();
    try {
      final full = await _readerService.extractFullContent(article.url);
      if (full != null && full.trim().isNotEmpty) {
        article.fullContent = full;
        final s = _storageService.getStoredArticle(article.id);
        if (s != null) { s.fullContent = full; await s.save(); }
        if (article.translatedTitle != null) {
          await translateArticle(article);
        }
        _fetchFailedIds.remove(article.id);
      } else {
        _fetchFailedIds.add(article.id);
      }
    } catch (e) {
      _fetchFailedIds.add(article.id);
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
    _errorMap[categoryId] = 'Wystąpił problem z pobieraniem danych. Spróbuj ponownie później.';
    debugPrint('Sowa NewsProvider Error [$categoryId]: $e');
  }

  List<Article>? _cachedSavedArticles;

  List<Article> get savedArticles {
    return _cachedSavedArticles ??= _storageService.getSavedArticles();
  }

  void _invalidateSavedCache() {
    _cachedSavedArticles = null;
  }

  List<Article> getArticlesWithTag(String tagId) => _storageService.getArticlesWithTag(tagId);

  Future<void> toggleArticleTag(Article article, String tagId) async {
    await _storageService.toggleArticleTag(article, tagId);
    _invalidateSavedCache();
    notifyListeners();
  }
}
