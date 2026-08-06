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

  DateTime? _lastSwipeUpTime;
  bool _showSwipeHint = false;
  double _pointerStartY = 0;
  DateTime? _pointerStartTime;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _scrollController.addListener(_scrollListener);
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  bool get _canFetch {
    final provider = context.read<NewsProvider>();
    final hasFullContent = widget.article.fullContent != null && widget.article.fullContent!.trim().isNotEmpty;
    return !hasFullContent && !provider.isFetchingFullContent && !RssService.isGoogleNewsUrl(widget.article.url);
  }

  void _handleSwipeUp() {
    if (!_canFetch) return;
    final now = DateTime.now();
    if (_lastSwipeUpTime != null && now.difference(_lastSwipeUpTime!) < const Duration(milliseconds: 800)) {
      setState(() {
        _showSwipeHint = false;
        _lastSwipeUpTime = null;
      });
      context.read<NewsProvider>().fetchFullArticleContent(widget.article);
    } else {
      _lastSwipeUpTime = now;
      setState(() => _showSwipeHint = true);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _showSwipeHint) setState(() => _showSwipeHint = false);
      });
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      if (!widget.article.isRead) {
        context.read<NewsProvider>().markArticleRead(widget.article);
      }
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerStartY = event.position.dy;
    _pointerStartTime = DateTime.now();
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_pointerStartTime == null) return;
    final dy = event.position.dy - _pointerStartY;
    final dt = DateTime.now().difference(_pointerStartTime!).inMilliseconds;
    if (dt < 500 && dy < -25) {
      _handleSwipeUp();
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
    if (seconds > article.readTimeSeconds) {
      article.readTimeSeconds = seconds;
    }
    if (seconds >= _kReadThresholdSeconds && !article.isRead) {
      context.read<NewsProvider>().markArticleRead(article);
    }
  }

  Article get article => widget.article;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerUp,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: article.imageUrl != null
                    ? CachedNetworkImage(imageUrl: article.imageUrl!, fit: BoxFit.cover)
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
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.translate, color: Colors.blueAccent),
                      onPressed: provider.isTranslating ? null : () => provider.translateArticle(article),
                      tooltip: 'Tłumacz na polski',
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => SharePlus.instance.share(ShareParams(text: '${article.title}\n\n${article.url}')),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_browser),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ArticleWebViewScreen(url: article.url, title: article.title),
                    ));
                  },
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          article.sourceName.toUpperCase(),
                          style: TextStyle(
                            color: AppTheme.accentFor(context),
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
                    Text(
                      article.translatedTitle ?? article.title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(height: 1.2),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    Consumer<NewsProvider>(
                      builder: (context, provider, child) {
                        final hasFullContent = article.fullContent != null && article.fullContent!.trim().isNotEmpty;

                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeIn,
                          switchOutCurve: Curves.easeOut,
                          child: _buildContentBody(context, provider, hasFullContent),
                        );
                      },
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentBody(BuildContext context, NewsProvider provider, bool hasFullContent) {
    if (provider.isFetchingFullContent || provider.isTranslating) {
      return Column(
        key: const ValueKey('loading'),
        children: [
          if (!hasFullContent)
            HtmlWidget(
              article.translatedDescription ?? (article.description.isNotEmpty ? article.description : ''),
              textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.6),
              onTapUrl: (url) async { await _launchUrl(context, url); return true; },
            ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            provider.isTranslating ? 'Sowa tłumaczy dla Ciebie...' : 'Sowa czyta artykuł dla Ciebie...',
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      );
    }

    if (!hasFullContent) {
      return Column(
        key: const ValueKey('snippet'),
        children: [
          HtmlWidget(
            article.translatedDescription ?? (article.description.isNotEmpty ? article.description : 'Brak treści artykułu.'),
            textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.6),
            onTapUrl: (url) async { await _launchUrl(context, url); return true; },
          ),
          if (_showSwipeHint) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF2E3238),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.keyboard_arrow_up, color: Colors.white70, size: 28),
                  SizedBox(height: 4),
                  Text(
                    'Przesuń jeszcze raz,\naby pobrać artykuł',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          _buildActionButtons(context, provider),
        ],
      );
    }

    return Column(
      key: const ValueKey('full'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HtmlWidget(
          article.translatedFullContent ?? article.fullContent!,
          textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.6),
          onTapUrl: (url) async { await _launchUrl(context, url); return true; },
        ),
        const SizedBox(height: 32),
        _buildActionButtons(context, provider),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, NewsProvider provider) {
    if (RssService.isGoogleNewsUrl(article.url)) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ArticleWebViewScreen(url: article.url, title: article.title),
            ));
          },
          icon: const Icon(Icons.auto_stories),
          label: const Text('CZYTAJ ARTYKUŁ'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentFor(context),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: provider.isFetchingFullContent
                ? null
                : () => provider.fetchFullArticleContent(article),
            icon: provider.isFetchingFullContent
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_stories, size: 16),
            label: Text(
              provider.fetchFailedIds.contains(article.id) ? 'SPRÓBUJ PONOWNIE' : 'PEŁNA TREŚĆ',
              style: const TextStyle(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentFor(context),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ArticleWebViewScreen(url: article.url, title: article.title),
              ));
            },
            icon: const Icon(Icons.open_in_browser, size: 16),
            label: const Text('W APLIKACJI', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accentFor(context),
              side: BorderSide(color: AppTheme.accentFor(context)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => provider.toggleLike(article),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: article.isLiked ? AppTheme.accentFor(context) : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              article.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
              color: article.isLiked ? Colors.white : Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 6),
        MenuAnchor(
          menuChildren: [
            MenuItemButton(
              onPressed: () => provider.toggleDislike(article),
              leadingIcon: Icon(article.isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined),
              child: Text(article.isDisliked ? 'Cofnij ocenę' : 'Nie podoba mi się'),
            ),
            MenuItemButton(
              onPressed: () => provider.toggleReadLater(article),
              leadingIcon: Icon(article.readLater ? Icons.timer : Icons.timer_outlined),
              child: Text(article.readLater ? 'Usuń z "Na później"' : 'Na później'),
            ),
            MenuItemButton(
              onPressed: () => provider.toggleFavorite(article),
              leadingIcon: Icon(article.isFavorite ? Icons.favorite : Icons.favorite_border),
              child: Text(article.isFavorite ? 'Usuń z ulubionych' : 'Ulubione'),
            ),
          ],
          builder: (context, menuController, child) {
            return GestureDetector(
              onTap: () => menuController.isOpen ? menuController.close() : menuController.open(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.more_vert,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 20,
                ),
              ),
            );
          },
        ),
      ],
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
