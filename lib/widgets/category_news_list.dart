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
    
    // Dla kategorii "warsaw" łączymy Google News + lokalny portal
    if (catId == 'warsaw') {
      final sources = <NewsSource>[];
      
      // Dodaj lokalny portal dla miasta (jeśli istnieje)
      final localSourceId = NewsSource.cityLocalSourceId[city];
      if (localSourceId != null) {
        final localSource = settings.allSources.firstWhere(
          (s) => s.id == localSourceId,
          orElse: () => NewsSource(id: '', name: '', rssUrl: '', categoryId: 'warsaw'),
        );
        if (localSource.id.isNotEmpty) {
          sources.add(localSource);
        }
      }
      
      // Dodaj Google News dla miasta
      final googleNewsUrl = NewsSource.googleNewsCityUrl(city);
      sources.add(NewsSource(
        id: 'google_news_$city',
        name: 'Google News - $city',
        rssUrl: googleNewsUrl,
        categoryId: 'warsaw',
      ));
      
      return sources;
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
      keywords: settings.keywords,
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

          content = Stack(
            children: [
              RefreshIndicator(
                color: AppTheme.accentGold,
                onRefresh: () => provider.fetchNews(
                  category: widget.category,
                  allSources: _getSourcesForCategory(settings),
                  enabledSourceIds: settings.enabledSourceIds,
                  keywords: settings.keywords,
                  forceRefresh: true,
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  addRepaintBoundaries: true,
                  scrollCacheExtent: const ScrollCacheExtent.pixels(1000.0),
                  itemCount: articles.length + (isAll ? 1 : 0),
                  itemBuilder: (context, index) {
                    // Sekcja Wszystkie: Nagłówek i Rekomendacje (zawsze na pozycji 0)
                    if (isAll) {
                      if (index == 0) {
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          child: _buildRecommendationsSection(
                            context, 
                            provider.recommendedArticles,
                          ),
                        );
                      }
                      final article = articles[index - 1];
                      return ArticleCard(article: article, onTap: () => _openArticle(context, article));
                    }

                    // Pozostałe kategorie
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      color: isDark ? Colors.black : Colors.white, 
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 80, color: Colors.redAccent),
          const SizedBox(height: 24),
          Text(
            'BRAK TREŚCI',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          Text(
            errorMessage ?? 'Nie udało się pobrać artykułów. Sprawdź połączenie z internetem i spróbuj ponownie.',
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => provider.fetchNews(
              category: widget.category,
              allSources: settings.allSources,
              enabledSourceIds: settings.enabledSourceIds,
              keywords: settings.keywords,
              forceRefresh: true,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentFor(context),
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            icon: const Icon(Icons.bolt),
            label: const Text('WYMUSZONE POBIERANIE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => settings.resetToDefaultSources(),
            child: Text('RESETUJ BAZĘ PORTALI', style: TextStyle(color: AppTheme.accentFor(context))),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection(BuildContext context, List<Article> recommended) {
    final hasRecs = recommended.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      key: ValueKey('recs_${hasRecs}_${recommended.length}'),
      color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasRecs) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppTheme.accentFor(context), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'DLA CIEBIE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      letterSpacing: 1.2, 
                      color: AppTheme.accentFor(context),
                      fontSize: 11,
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
            const SizedBox(height: 16),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Text(
              'NAJNOWSZE WIADOMOŚCI',
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                letterSpacing: 1.5, 
                fontSize: 10, 
                color: isDark ? Colors.grey : Colors.grey.shade600,
              ),
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: isDark ? Colors.white10 : Colors.grey.shade300),
        ],
      ),
    );
  }

  void _openArticle(BuildContext context, Article article) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ArticleDetailScreen(article: article)));
  }
}
