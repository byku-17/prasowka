import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/news_category.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/screens/article_detail_screen.dart';
import 'package:prasowka/screens/settings_screen.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/widgets/article_card.dart';
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
            icon: const Icon(Icons.settings),
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
                                builder: (_) => ArticleDetailScreen(article: article),
                              ),
                            ),
                          );
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
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, NewsProvider provider) {
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
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nie udało się pobrać artykułów sportowych.',
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              _hasFetched = false;
              _fetchIfNeeded();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentFor(context),
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            icon: const Icon(Icons.bolt),
            label: const Text('POBIERZ PONOWNIE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
