import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/screens/article_detail_screen.dart';
import 'package:prasowka/screens/settings_screen.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/widgets/article_card.dart';
import 'package:prasowka/widgets/empty_state_widget.dart';
import 'package:prasowka/widgets/scores_bar.dart';
import 'package:prasowka/widgets/local_info_bar.dart';
import 'package:prasowka/widgets/news_skeleton.dart';

/// Generic screen for a single category tab.
/// Used for the 2 configurable main tabs.
class CategoryTabScreen extends StatefulWidget {
  final String categoryId;
  const CategoryTabScreen({super.key, required this.categoryId});

  @override
  State<CategoryTabScreen> createState() => _CategoryTabScreenState();
}

class _CategoryTabScreenState extends State<CategoryTabScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;
  bool _hasFetched = false;

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

  void _fetchIfNeeded() {
    if (_hasFetched) return;
    _hasFetched = true;

    final settings = context.read<SettingsProvider>();
    final allSources = settings.allSources;
    final enabledIds = settings.enabledSourceIds;

    final catSources = allSources
        .where((s) => s.categoryId == widget.categoryId)
        .toList();

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

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
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
      body: Selector<NewsProvider, ({List<Article> articles, bool isLoading, bool hasEverLoaded})>(
        selector: (_, provider) => (
          articles: provider.getArticlesForCategory(widget.categoryId),
          isLoading: provider.isCategoryLoading(widget.categoryId),
          hasEverLoaded: provider.hasCategoryEverLoaded(widget.categoryId),
        ),
        builder: (context, data, child) {
          final articles = data.articles;
          final isLoading = data.isLoading;
          final hasEverLoaded = data.hasEverLoaded;

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

          return Column(
            children: [
              if (isSport) const ScoresBar(),
              if (isWarsaw) const LocalInfoBar(),
              Expanded(
                child: Stack(
                  children: [
                    RefreshIndicator(
                      color: AppTheme.accentGold,
                      onRefresh: () async {
                        _hasFetched = false;
                        _fetchIfNeeded();
                      },
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.zero,
                        addRepaintBoundaries: true,
                        itemCount: articles.length,
                        itemBuilder: (context, index) {
                          final article = articles[index];
                          return ArticleCard(
                            article: article,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ArticleDetailScreen(
                                  article: article,
                                  articles: articles,
                                  currentIndex: index,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_showBackToTop)
                      Positioned(
                        right: 16,
                        bottom: 80,
                        child: FloatingActionButton.small(
                          onPressed: _scrollToTop,
                          backgroundColor: AppTheme.accentGold,
                          foregroundColor: Colors.black,
                          elevation: 4,
                          child: const Icon(Icons.arrow_upward),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
