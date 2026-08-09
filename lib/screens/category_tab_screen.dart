import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/models/news_source.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/screens/article_detail_screen.dart';
import 'package:prasowka/screens/settings_screen.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/widgets/article_card.dart';
import 'package:prasowka/widgets/scroll_to_top_wrapper.dart';
import 'package:prasowka/widgets/empty_state_widget.dart';
import 'package:prasowka/widgets/scores_bar.dart';
import 'package:prasowka/widgets/local_info_bar.dart';
import 'package:prasowka/widgets/news_skeleton.dart';

/// Generic screen for a single category tab.
/// Used for the 2 configurable main tabs.
class CategoryTabScreen extends StatefulWidget {
  final String categoryId;
  final ValueNotifier<int>? refreshNotifier;
  const CategoryTabScreen({super.key, required this.categoryId, this.refreshNotifier});

  @override
  State<CategoryTabScreen> createState() => _CategoryTabScreenState();
}

class _CategoryTabScreenState extends State<CategoryTabScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _hasFetched = false;

  @override
  void initState() {
    super.initState();
    widget.refreshNotifier?.addListener(_onRefreshTap);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchIfNeeded());
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_onRefreshTap);
    _scrollController.dispose();
    super.dispose();
  }

  void _onRefreshTap() {
    _hasFetched = false;
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
    _fetchIfNeeded();
  }

  void _fetchIfNeeded() {
    if (_hasFetched) return;
    _hasFetched = true;

    final settings = context.read<SettingsProvider>();
    final allSources = settings.allSources;
    final enabledIds = settings.enabledSourceIds;

    List<NewsSource> catSources;
    if (widget.categoryId == 'warsaw') {
      catSources = NewsSource.getCitySources(settings.preferredCity, allSources);
    } else {
      catSources = allSources
          .where((s) => s.categoryId == widget.categoryId)
          .toList();
    }

    final category = settings.getCategoryById(widget.categoryId);
    if (category == null) return;

    context.read<NewsProvider>().fetchNews(
      category: category,
      allSources: catSources,
      enabledSourceIds: enabledIds,
      keywords: settings.keywords,
      forceRefresh: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final category = settings.getCategoryById(widget.categoryId);
    // Dla kategorii 'warsaw' wyświetl nazwę miasta zamiast "Lokalne"
    String title;
    if (widget.categoryId == 'warsaw') {
      title = settings.preferredCity.toUpperCase();
    } else {
      title = category?.name.toUpperCase() ?? widget.categoryId.toUpperCase();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: Colors.grey.shade600),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Selector<NewsProvider, ({List<Article> articles, bool isLoading, bool hasEverLoaded, List<Article> recommended})>(
        selector: (_, provider) => (
          articles: provider.getArticlesForCategory(widget.categoryId),
          isLoading: provider.isCategoryLoading(widget.categoryId),
          hasEverLoaded: provider.hasCategoryEverLoaded(widget.categoryId),
          recommended: provider.recommendedArticles,
        ),
        builder: (context, data, child) {
          final articles = data.articles;
          final isLoading = data.isLoading;
          final hasEverLoaded = data.hasEverLoaded;
          final provider = context.read<NewsProvider>();
          final recommendedIds = provider.getRecommendedFrom(articles).map((a) => a.id).toSet();

          if (articles.isEmpty && (isLoading || !hasEverLoaded)) {
            return ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => const NewsSkeleton(),
            );
          }

          if (articles.isEmpty && hasEverLoaded) {
            return EmptyStateWidget(
              message: 'Nie udało się pobrać artykułów.',
              onRetry: () {
                _hasFetched = false;
                _fetchIfNeeded();
              },
            );
          }

          final isSport = widget.categoryId == 'sport';
          final isWarsaw = widget.categoryId == 'warsaw';
          final sortedArticles = [
            ...articles.where((a) => recommendedIds.contains(a.id)),
            ...articles.where((a) => !recommendedIds.contains(a.id)),
          ];

          return Column(
            children: [
              if (isSport) const ScoresBar(),
              if (isWarsaw) const LocalInfoBar(),
              Expanded(
                child: ScrollToTopWrapper(
                  scrollController: _scrollController,
                  child: RefreshIndicator(
                    color: AppTheme.accentGold,
                    onRefresh: () async {
                      _hasFetched = false;
                      _fetchIfNeeded();
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.zero,
                      addRepaintBoundaries: true,
                      itemCount: sortedArticles.length,
                      itemBuilder: (context, index) {
                        final article = sortedArticles[index];
                        final isRec = recommendedIds.contains(article.id);
                        return ArticleCard(
                          article: article,
                          isRecommended: isRec,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ArticleDetailScreen(
                                article: article,
                                articles: sortedArticles,
                                currentIndex: index,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
