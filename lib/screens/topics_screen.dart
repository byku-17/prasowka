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

class TopicsScreen extends StatelessWidget {
  const TopicsScreen({super.key});

  /// Kategorie which have their own tabs (excluded from grid)
  static const _excludedIds = {'all', 'warsaw', 'sport', 'api_news'};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppTheme.accentFor(context);
    final settings = context.watch<SettingsProvider>();

    // Filtruj wg aktywnych kategorii + wykluczone taby
    final topicCategories = settings.allCategoriesOrdered
        .where((c) => !_excludedIds.contains(c.id) && settings.isCategoryActive(c.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'TEMATY',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16),
        ),
        centerTitle: true,
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
      body: CustomScrollView(
        slivers: [
          if (topicCategories.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.6,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final cat = topicCategories[index];
                    return _TopicCard(category: cat);
                  },
                  childCount: topicCategories.length,
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            sliver: SliverToBoxAdapter(
              child: _ApiNewsTile(isDark: isDark, accent: accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  final NewsCategory category;
  const _TopicCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppTheme.accentFor(context);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _CategoryArticlesScreen(category: category),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(category.icon, color: accent, size: 28),
            const SizedBox(height: 6),
            Text(
              category.name.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1.0,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ApiNewsTile extends StatelessWidget {
  final bool isDark;
  final Color accent;
  const _ApiNewsTile({required this.isDark, required this.accent});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _CategoryArticlesScreen(
            category: NewsCategory(id: 'api_news', name: 'API News', iconCode: Icons.api.codePoint),
          ),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.api, color: accent, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'API NEWS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.0,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Artykuły z NewsAPI.org',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}

class _CategoryArticlesScreen extends StatefulWidget {
  final NewsCategory category;
  const _CategoryArticlesScreen({required this.category});

  @override
  State<_CategoryArticlesScreen> createState() => _CategoryArticlesScreenState();
}

class _CategoryArticlesScreenState extends State<_CategoryArticlesScreen> {
  bool _hasFetched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchIfNeeded());
  }

  void _fetchIfNeeded() {
    if (_hasFetched) return;
    _hasFetched = true;

    final settings = context.read<SettingsProvider>();
    final allSources = settings.allSources;
    final enabledIds = settings.enabledSourceIds;

    final catSources = allSources
        .where((s) => s.categoryId == widget.category.id)
        .toList();

    context.read<NewsProvider>().fetchNews(
      category: widget.category,
      allSources: catSources,
      enabledSourceIds: enabledIds,
      keywords: settings.keywords,
      forceRefresh: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.category.name.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16),
        ),
      ),
      body: Consumer<NewsProvider>(
        builder: (context, provider, child) {
          final articles = provider.getArticlesForCategory(widget.category.id);
          final isLoading = provider.isCategoryLoading(widget.category.id);
          final hasEverLoaded = provider.hasCategoryEverLoaded(widget.category.id);

          if (articles.isEmpty && (isLoading || !hasEverLoaded)) {
            return ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => const NewsSkeleton(),
            );
          }

          if (articles.isEmpty && hasEverLoaded) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.wifi_off, size: 64, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text(
                    'BRAK TREŚCI',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Nie udało się pobrać artykułów.',
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      _hasFetched = false;
                      _fetchIfNeeded();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentFor(context),
                      foregroundColor: isDark ? Colors.black : Colors.white,
                    ),
                    icon: const Icon(Icons.bolt),
                    label: const Text('POBIERZ PONOWNIE', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.accentGold,
            onRefresh: () async {
              _hasFetched = false;
              _fetchIfNeeded();
            },
            child: ListView.builder(
              padding: EdgeInsets.zero,
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
          );
        },
      ),
    );
  }
}
