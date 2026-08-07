import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/news_category.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/screens/article_detail_screen.dart';
import 'package:prasowka/screens/settings_screen.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/widgets/article_card.dart';
import 'package:prasowka/widgets/empty_state_widget.dart';
import 'package:prasowka/widgets/news_skeleton.dart';
import 'package:prasowka/widgets/scores_bar.dart';

class SportScreen extends StatefulWidget {
  const SportScreen({super.key});

  @override
  State<SportScreen> createState() => _SportScreenState();
}

class _SportScreenState extends State<SportScreen> {
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

    final sportSources = allSources
        .where((s) => s.categoryId == 'sport')
        .toList();

    context.read<NewsProvider>().fetchNews(
      category: NewsCategory(
        id: 'sport',
        name: 'Sport',
        iconCode: Icons.sports_soccer.codePoint,
      ),
      allSources: sportSources,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SPORT',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16),
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
      body: Column(
        children: [
          const ScoresBar(),
          Expanded(
            child: Consumer<NewsProvider>(
              builder: (context, provider, child) {
                final articles = provider.getArticlesForCategory('sport');
                final isLoading = provider.isCategoryLoading('sport');
                final hasEverLoaded = provider.hasCategoryEverLoaded('sport');

                // Shimmer
                if (articles.isEmpty && (isLoading || !hasEverLoaded)) {
                  return ListView.builder(
                    itemCount: 5,
                    itemBuilder: (context, index) => const NewsSkeleton(),
                  );
                }

                // Empty state
                if (articles.isEmpty && hasEverLoaded) {
                  return _buildEmptyState(context, provider);
                }

                // Lista artykułów
                return Stack(
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, NewsProvider provider) {
    return EmptyStateWidget(
      message: 'Nie udało się pobrać artykułów sportowych.',
      onRetry: () {
        _hasFetched = false;
        _fetchIfNeeded();
      },
    );
  }
}
