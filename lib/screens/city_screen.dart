import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/news_category.dart';
import 'package:prasowka/models/news_source.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/screens/article_detail_screen.dart';
import 'package:prasowka/screens/settings_screen.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/widgets/article_card.dart';
import 'package:prasowka/widgets/local_info_bar.dart';
import 'package:prasowka/widgets/news_skeleton.dart';

class CityScreen extends StatefulWidget {
  const CityScreen({super.key});

  @override
  State<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends State<CityScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;
  String? _lastFetchCityHash;

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
    final settings = context.read<SettingsProvider>();
    final cityHash = "${settings.preferredCity}_${settings.cityCoordinates.latitude}_${settings.cityCoordinates.longitude}";
    if (_lastFetchCityHash == cityHash) return;
    _lastFetchCityHash = cityHash;

    final city = settings.preferredCity;
    final allSources = settings.allSources;
    final enabledIds = settings.enabledSourceIds;

    // Buduj źródła: lokalny portal + Google News
    final sources = <NewsSource>[];
    final localSourceId = NewsSource.cityLocalSourceId[city];
    if (localSourceId != null) {
      final localSource = allSources.firstWhere(
        (s) => s.id == localSourceId,
        orElse: () => NewsSource(id: '', name: '', rssUrl: '', categoryId: 'warsaw'),
      );
      if (localSource.id.isNotEmpty) {
        sources.add(localSource);
      }
    }

    final googleNewsUrl = NewsSource.googleNewsCityUrl(city);
    sources.add(NewsSource(
      id: 'google_news_$city',
      name: 'Google News - $city',
      rssUrl: googleNewsUrl,
      categoryId: 'warsaw',
    ));

    context.read<NewsProvider>().fetchNews(
      category: NewsCategory(
        id: 'warsaw',
        name: 'Lokalne',
        iconCode: Icons.location_city.codePoint,
      ),
      allSources: sources,
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
    final settings = context.watch<SettingsProvider>();
    final city = settings.preferredCity;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          city.toUpperCase(),
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
      body: Column(
        children: [
          const LocalInfoBar(),
          Expanded(
            child: Consumer<NewsProvider>(
              builder: (context, provider, child) {
                final articles = provider.getArticlesForCategory('warsaw');
                final isLoading = provider.isCategoryLoading('warsaw');
                final hasEverLoaded = provider.hasCategoryEverLoaded('warsaw');

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
                        _lastFetchCityHash = null;
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
            'Nie udało się pobrać artykułów dla Twojego miasta.',
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              _lastFetchCityHash = null;
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
