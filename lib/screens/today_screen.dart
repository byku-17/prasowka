import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/models/news_category.dart';
import 'package:prasowka/models/news_source.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/screens/article_detail_screen.dart';
import 'package:prasowka/screens/notifications_screen.dart';
import 'package:prasowka/widgets/scroll_to_top_wrapper.dart';
import 'package:prasowka/screens/settings_screen.dart';
import 'package:prasowka/services/notification_history.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/widgets/article_card.dart';
import 'package:prasowka/widgets/empty_state_widget.dart';
import 'package:prasowka/widgets/news_skeleton.dart';

class TodayScreen extends StatefulWidget {
  final ValueNotifier<int>? refreshNotifier;
  const TodayScreen({super.key, this.refreshNotifier});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _hasFetched = false;
  final Set<String> _dismissedArticleIds = {};
  static const int _initialLoad = 20;
  static const int _loadMoreStep = 20;
  int _visibleCount = _initialLoad;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshUnread();
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
    setState(() => _visibleCount = _initialLoad);
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic);
    _fetchIfNeeded();
  }

  void _refreshUnread() async {
    await NotificationHistory().refreshBox();
    if (mounted) setState(() => _unreadCount = NotificationHistory().unreadCount);
  }

  void _fetchIfNeeded() {
    if (_hasFetched) return;
    _hasFetched = true;

    final settings = context.read<SettingsProvider>();
    final provider = context.read<NewsProvider>();
    final allSources = settings.allSources;
    final enabledIds = settings.enabledSourceIds;

    // Filtruj do topSourceIds + custom sources (lub wszystkie jeśli toggle)
    final topSources = settings.showAllSources
        ? allSources
        : allSources
            .where((s) => NewsSource.topSourceIds.contains(s.id) || s.id.startsWith('custom_'))
            .toList();

    provider.fetchNews(
      category: NewsCategory(
        id: 'all',
        name: 'Wszystkie',
        iconCode: Icons.auto_awesome.codePoint,
      ),
      allSources: topSources,
      enabledSourceIds: enabledIds,
      keywords: settings.keywords,
      forceRefresh: true,
    );
  }

  void _dismissArticle(Article article) {
    setState(() => _dismissedArticleIds.add(article.url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ukryto: ${article.title}'),
        action: SnackBarAction(
          label: 'Cofnij',
          onPressed: () => setState(() => _dismissedArticleIds.remove(article.url)),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    final hasUnread = _unreadCount > 0;
    return IconButton(
      icon: Badge(
        isLabelVisible: hasUnread,
        backgroundColor: Colors.red,
        offset: const Offset(6, -6),
        label: Text(
          _unreadCount > 99 ? '99+' : '$_unreadCount',
          style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        child: Icon(
          hasUnread ? Icons.notifications : Icons.notifications_outlined,
          color: hasUnread ? Colors.red : Colors.grey.shade600,
        ),
      ),
      tooltip: 'Powiadomienia',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        ).then((_) => _refreshUnread());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _buildNotificationBell(context),
        title: Text(
          'PRASÓWKA',
          style: GoogleFonts.syne(
            letterSpacing: 2.0,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
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
      body: Selector<NewsProvider, ({List<Article> articles, bool isLoading, bool hasEverLoaded, List<Article> recommended})>(
        selector: (_, provider) => (
          articles: provider.getArticlesForCategory('all'),
          isLoading: provider.isCategoryLoading('all'),
          hasEverLoaded: provider.hasCategoryEverLoaded('all'),
          recommended: provider.recommendedArticles,
        ),
        builder: (context, data, child) {
          final articles = data.articles.where((a) => !_dismissedArticleIds.contains(a.url)).toList();
          final isLoading = data.isLoading;
          final hasEverLoaded = data.hasEverLoaded;
          final provider = context.read<NewsProvider>();
          final recommendedIds = provider.getRecommendedFrom(articles).map((a) => a.id).toSet();

          // Shimmer
          if (articles.isEmpty && (isLoading || !hasEverLoaded)) {
            return ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => const NewsSkeleton(),
            );
          }

          // Empty state
          if (articles.isEmpty && hasEverLoaded) {
            return _buildEmptyState(context, context.read<NewsProvider>());
          }

          // Lista z rekomendacjami
          final sortedArticles = [
            ...articles.where((a) => recommendedIds.contains(a.id)),
            ...articles.where((a) => !recommendedIds.contains(a.id)),
          ];
          final visibleArticles = sortedArticles.take(_visibleCount).toList();
          return ScrollToTopWrapper(
            scrollController: _scrollController,
            child: RefreshIndicator(
                color: AppTheme.accentGold,
                onRefresh: () async {
                  _hasFetched = false;
                  setState(() => _visibleCount = _initialLoad);
                  _fetchIfNeeded();
                },
                child: ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  addRepaintBoundaries: true,
                  itemCount: (sortedArticles.length < _visibleCount ? sortedArticles.length : _visibleCount) + (sortedArticles.length > _visibleCount ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < visibleArticles.length) {
                      final article = visibleArticles[index];
                      final isRec = recommendedIds.contains(article.id);
                      return LongPressDismissible(
                        onDismiss: () => _dismissArticle(article),
                        child: ArticleCard(
                          article: article,
                          isRecommended: isRec,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ArticleDetailScreen(
                                article: article,
                                articles: visibleArticles,
                                currentIndex: index,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    // Load more button
                    if (sortedArticles.length > _visibleCount) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() => _visibleCount += _loadMoreStep);
                            },
                            icon: const Icon(Icons.expand_more, size: 18),
                            label: Text('Pokaż więcej (${sortedArticles.length - _visibleCount})'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentFor(context),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, NewsProvider provider) {
    return EmptyStateWidget(
      message: 'Nie udało się pobrać artykułów. Sprawdź połączenie z internetem i spróbuj ponownie.',
      onRetry: () {
        _hasFetched = false;
        _fetchIfNeeded();
      },
    );
  }
}

class LongPressDismissible extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;

  const LongPressDismissible({super.key, required this.child, required this.onDismiss});

  @override
  State<LongPressDismissible> createState() => _LongPressDismissibleState();
}

class _LongPressDismissibleState extends State<LongPressDismissible> {
  bool _isDismissing = false;

  void _handleLongPress() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_off),
              title: const Text('Ukryj ten artykuł'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _isDismissing = true);
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) widget.onDismiss();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissing) {
      return AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: const SizedBox.shrink(),
      );
    }
    return GestureDetector(
      onLongPress: _handleLongPress,
      child: widget.child,
    );
  }
}
