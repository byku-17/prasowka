import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/models/news_category.dart';
import 'package:prasowka/models/news_source.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/screens/article_detail_screen.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/widgets/article_card.dart';
import 'package:prasowka/widgets/news_skeleton.dart';
import 'package:prasowka/widgets/scores_bar.dart';
import 'package:prasowka/widgets/local_info_bar.dart';

class CategoryNewsList extends StatefulWidget {
  final NewsCategory category;

  const CategoryNewsList({super.key, required this.category});

  @override
  State<CategoryNewsList> createState() => _CategoryNewsListState();
}

class _CategoryNewsListState extends State<CategoryNewsList> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;
  String? _lastFetchCityHash;

  @override
  bool get wantKeepAlive => true;

  List<NewsSource> _getSourcesForCategory(SettingsProvider settings) {
    final city = settings.preferredCity;
    final catId = widget.category.id;
    
    // Dla kategorii "warsaw" podmień źródła na te przypisane do wybranego miasta
    if (catId == 'warsaw') {
      final sourceIds = NewsSource.cityRssSourceIds[city];
      if (sourceIds != null) {
        return settings.allSources.where((s) => sourceIds.contains(s.id)).toList();
      }
      return settings.allSources.where((s) => s.categoryId == 'warsaw').toList();
    }

    // Dla "api_news" nie potrzebujemy źródeł RSS
    if (catId == 'api_news') return [];

    // Dla "all" zwróć top źródła
    if (catId == 'all') {
      return settings.allSources.where((s) => NewsSource.topSourceIds.contains(s.id) || s.id.startsWith('custom_')).toList();
    }

    // Dla pozostałych kategorii — filtruj po categoryId
    return settings.allSources.where((s) => s.categoryId == catId).toList();
  }

  void _fetchIfNeeded() {
    final settings = context.read<SettingsProvider>();
    final cityHash = "${settings.preferredCity}_${settings.cityCoordinates.latitude}_${settings.cityCoordinates.longitude}";
    if (_lastFetchCityHash == cityHash) return;
    _lastFetchCityHash = cityHash;

    context.read<NewsProvider>().fetchNews(
      category: widget.category,
      allSources: _getSourcesForCategory(settings),
      enabledSourceIds: settings.enabledSourceIds,
      favoriteTeams: settings.favoriteTeams,
      forceRefresh: true,
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 600 && !_showBackToTop) {
        setState(() => _showBackToTop = true);
      } else if (_scrollController.offset <= 600 && _showBackToTop) {
        setState(() => _showBackToTop = false);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchIfNeeded());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final settings = context.watch<SettingsProvider>();
    
    // Sprawdź czy miasto się zmieniło i zaplanuj odświeżenie
    final cityHash = "${settings.preferredCity}_${settings.cityCoordinates.latitude}_${settings.cityCoordinates.longitude}";
    if (_lastFetchCityHash != cityHash) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchIfNeeded());
    }
    
    final bool isSport = widget.category.id == 'sport';
    final bool isWarsaw = widget.category.id == 'warsaw';

    final newsContent = Consumer<NewsProvider>(
      builder: (context, provider, child) {
        final articles = provider.getArticlesForCategory(widget.category.id);
        final isLoading = provider.isCategoryLoading(widget.category.id);
        final hasEverLoaded = provider.hasCategoryEverLoaded(widget.category.id);

        Widget content;

        // 1. Jeśli mamy artykuły -> Pokaż listę
        if (articles.isNotEmpty) {
          final bool isAll = widget.category.id == 'all';
          final bool showRecs = isAll && provider.recommendedArticles.isNotEmpty;

          content = Stack(
            children: [
              RefreshIndicator(
                color: AppTheme.accentGold,
                onRefresh: () => provider.fetchNews(
                  category: widget.category,
                  allSources: _getSourcesForCategory(settings),
                  enabledSourceIds: settings.enabledSourceIds,
                  favoriteTeams: settings.favoriteTeams,
                  forceRefresh: true,
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  addRepaintBoundaries: true,
                  scrollCacheExtent: const ScrollCacheExtent.pixels(1000.0),
                  itemCount: articles.length + (showRecs ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Sekcja Wszystkie: Rekomendacje na górze
                    if (showRecs) {
                      if (index == 0) return RepaintBoundary(child: _buildRecommendationsSection(context, provider.recommendedArticles));
                      final article = articles[index - 1];
                      return ArticleCard(article: article, onTap: () => _openArticle(context, article));
                    }

                    // Reszta
                    final article = articles[index];
                    return ArticleCard(article: article, onTap: () => _openArticle(context, article));
                  },
                ),
              ),
              if (_showBackToTop)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    onPressed: _scrollToTop,
                    backgroundColor: AppTheme.accentGold,
                    foregroundColor: Colors.black,
                    elevation: 4,
                    child: const Icon(Icons.arrow_upward),
                  ),
                ),
            ],
          );
        } else if (isLoading || !hasEverLoaded) {
          // 2. Jeśli pusto i ładowanie -> SHIMMER
          content = ListView.builder(
            itemCount: 5,
            itemBuilder: (context, index) => const NewsSkeleton(),
          );
        } else {
          // 3. Jeśli faktycznie pusto po zakończeniu -> EMPTY STATE
          final errorMessage = provider.getCategoryError(widget.category.id);
          content = _buildEmptyState(context, provider, settings, errorMessage);
        }

        return content;
      },
    );

    if (isSport || isWarsaw) {
      return Column(
        children: [
          if (isSport) const ScoresBar(),
          if (isWarsaw) const LocalInfoBar(),
          Expanded(child: newsContent),
        ],
      );
    }

    return newsContent;
  }

  Widget _buildEmptyState(BuildContext context, NewsProvider provider, SettingsProvider settings, String? errorMessage) {
    return Container(
      width: double.infinity,
      color: Colors.black, 
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 80, color: Colors.redAccent),
          const SizedBox(height: 24),
          const Text(
            'BRAK TREŚCI',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          Text(
            errorMessage ?? 'Nie udało się pobrać artykułów. Sprawdź połączenie z internetem i spróbuj ponownie.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => provider.fetchNews(
              category: widget.category,
              allSources: settings.allSources,
              enabledSourceIds: settings.enabledSourceIds,
              favoriteTeams: settings.favoriteTeams,
              forceRefresh: true,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            icon: const Icon(Icons.bolt),
            label: const Text('WYMUSZONE POBIERANIE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => settings.resetToDefaultSources(),
            child: const Text('RESETUJ BAZĘ PORTALI', style: TextStyle(color: AppTheme.accentGold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection(BuildContext context, List<Article> recommended) {
    return Container(
      color: Colors.white.withValues(alpha: 0.03), // Delikatne wyróżnienie tła
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: AppTheme.accentGold, size: 18),
                SizedBox(width: 8),
                Text(
                  'DLA CIEBIE',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 1.2, 
                    color: AppTheme.accentGold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: recommended.length,
              itemBuilder: (context, index) {
                final a = recommended[index];
                return RepaintBoundary(
                  child: ArticleCard(article: a, isSmall: true, onTap: () => _openArticle(context, a)),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'NAJNOWSZE WIADOMOŚCI',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 10, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  void _openArticle(BuildContext context, Article article) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ArticleDetailScreen(article: article)));
  }
}
