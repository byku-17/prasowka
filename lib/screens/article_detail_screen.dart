import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/services/rss_service.dart';
import 'package:prasowka/screens/article_webview_screen.dart';

/// Próg czasu (w sekundach), po którym artykuł jest uznawany za "przeczytany"
const int _kReadThresholdSeconds = 20;

class ArticleDetailScreen extends StatefulWidget {
  final Article article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late final Stopwatch _stopwatch;
  Timer? _tickTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    
    _scrollController.addListener(_scrollListener);

    // Co 1s odśwież UI
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (!widget.article.isRead) {
        context.read<NewsProvider>().markArticleRead(widget.article);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _tickTimer?.cancel();
    _stopwatch.stop();
    final elapsed = _stopwatch.elapsed.inSeconds;
    _markReadIfEnough(elapsed);
    super.dispose();
  }

  void _markReadIfEnough(int seconds) {
    final article = widget.article;
    // Zaktualizuj czas czytania
    if (seconds > article.readTimeSeconds) {
      article.readTimeSeconds = seconds;
    }
    // Oznacz jako przeczytany jeśli wystarczająco długo czytał
    if (seconds >= _kReadThresholdSeconds && !article.isRead) {
      context.read<NewsProvider>().markArticleRead(article);
    }
  }

  Article get article => widget.article;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: article.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: article.imageUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(color: const Color(0xFF1E2126)),
            ),
            actions: [
              if (article.isRead)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                ),
              Consumer<NewsProvider>(
                builder: (context, provider, child) {
                  final isPolish = provider.isArticlePolish(article);
                  final needsTranslation = !isPolish && (
                    article.translatedTitle == null ||
                    (article.fullContent != null && article.translatedFullContent == null)
                  );

                  if (!needsTranslation) return const SizedBox.shrink();

                  return IconButton(
                    icon: provider.isTranslating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                          )
                        : const Icon(Icons.translate, color: Colors.blueAccent),
                    onPressed: provider.isTranslating
                        ? null
                        : () => provider.translateArticle(article),
                    tooltip: 'Tłumacz na polski',
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => Share.share('${article.title}\n\n${article.url}'),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_browser),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ArticleWebViewScreen(
                        url: article.url,
                        title: article.title,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        article.sourceName.toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.accentGold,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('dd.MM.yyyy HH:mm').format(article.publishedAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Consumer<NewsProvider>(
                    builder: (context, provider, child) {
                      return Text(
                        article.translatedTitle ?? article.title,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          height: 1.2,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  const Divider(),
                  const SizedBox(height: 16),

                  Consumer<NewsProvider>(
                    builder: (context, provider, child) {
                      final hasFullContent = article.fullContent != null && article.fullContent!.trim().isNotEmpty;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (provider.isFetchingFullContent || provider.isTranslating)
                            Center(
                              child: Column(
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 12),
                                  Text(
                                    provider.isTranslating ? 'Sowa tłumaczy dla Ciebie...' : 'Sowa czyta artykuł dla Ciebie...',
                                    style: const TextStyle(fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                            )
                          else if (!hasFullContent)
                            Column(
                              children: [
                                HtmlWidget(
                                  article.translatedDescription ?? (article.description.isNotEmpty ? article.description : 'Brak treści artykułu.'),
                                  textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontSize: 18,
                                    height: 1.6,
                                  ),
                                  onTapUrl: (url) async {
                                    await _launchUrl(context, url);
                                    return true;
                                  },
                                ),
                                const SizedBox(height: 24),
                                if (RssService.isGoogleNewsUrl(article.url))
                                  Center(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ArticleWebViewScreen(
                                              url: article.url,
                                              title: article.title,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.auto_stories),
                                      label: const Text('CZYTAJ ARTYKUŁ'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.accentGold,
                                        foregroundColor: AppTheme.primaryNavy,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      ),
                                    ),
                                  )
                                else ...[
                                  Center(
                                    child: ElevatedButton.icon(
                                      onPressed: provider.isFetchingFullContent
                                          ? null
                                          : () => provider.fetchFullArticleContent(article),
                                      icon: provider.isFetchingFullContent
                                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                          : const Icon(Icons.auto_stories),
                                      label: Text(provider.fetchFailedIds.contains(article.id)
                                          ? 'SPRÓBUJ PONOWNIE'
                                          : 'POBIERZ PEŁNĄ TREŚĆ'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.accentGold,
                                        foregroundColor: AppTheme.primaryNavy,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Center(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ArticleWebViewScreen(
                                              url: article.url,
                                              title: article.title,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.open_in_browser, size: 18),
                                      label: const Text('CZYTAJ W APLIKACJI'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.accentGold,
                                        side: const BorderSide(color: AppTheme.accentGold),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                HtmlWidget(
                                  article.translatedFullContent ?? article.fullContent!,
                                  textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontSize: 18,
                                    height: 1.6,
                                  ),
                                  onTapUrl: (url) async {
                                    await _launchUrl(context, url);
                                    return true;
                                  },
                                ),
                                const SizedBox(height: 24),
                                Center(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ArticleWebViewScreen(
                                            url: article.url,
                                            title: article.title,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.open_in_browser, size: 18),
                                    label: const Text('CZYTAJ W APLIKACJI'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.accentGold,
                                      side: const BorderSide(color: AppTheme.accentGold),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      );
                    },
                  ),


                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Consumer<NewsProvider>(
        builder: (context, provider, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'like',
                onPressed: () => provider.toggleLike(article),
                backgroundColor: article.isLiked ? AppTheme.accentGold : Colors.white,
                child: Icon(article.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined, color: article.isLiked ? Colors.white : Colors.grey),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'dislike',
                onPressed: () => provider.toggleDislike(article),
                backgroundColor: article.isDisliked ? Colors.red : Colors.white,
                child: Icon(article.isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined, color: article.isDisliked ? Colors.white : Colors.grey),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'readLater',
                onPressed: () => provider.toggleReadLater(article),
                backgroundColor: article.readLater ? AppTheme.accentGold : Colors.white,
                child: Icon(
                  article.readLater ? Icons.timer : Icons.timer_outlined,
                  color: article.readLater ? Colors.white : AppTheme.primaryNavy,
                ),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'favorite',
                onPressed: () => provider.toggleFavorite(article),
                backgroundColor: article.isFavorite ? Colors.red : Colors.white,
                child: Icon(
                  article.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: article.isFavorite ? Colors.white : Colors.red,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nie udało się otworzyć linku')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nieprawidłowy link')),
        );
      }
    }
  }
}
