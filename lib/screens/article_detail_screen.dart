import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/services/rss_service.dart';
import 'package:prasowka/services/reading_history.dart';
import 'package:prasowka/services/image_cache_manager.dart';
import 'package:prasowka/screens/article_webview_screen.dart';
import 'package:prasowka/widgets/tag_picker_bottom_sheet.dart';

const int _kReadThresholdSeconds = 20;

class ArticleDetailScreen extends StatefulWidget {
  final Article article;
  final List<Article>? articles;
  final int? currentIndex;
  const ArticleDetailScreen({super.key, required this.article, this.articles, this.currentIndex});
  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late final Stopwatch _stopwatch;
  Timer? _tickTimer;
  final ScrollController _scrollController = ScrollController();
  late int _currentIndex;
  late final PageController _pageController;

  double _pointerStartY = 0;
  DateTime? _pointerStartTime;

  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex ?? 0;
    _pageController = PageController(initialPage: _currentIndex);
    _stopwatch = Stopwatch()..start();
    _scrollController.addListener(_scrollListener);
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _initTts();
    _recordHistory(widget.article);
  }

  void _initTts() {
    _tts.setLanguage('pl-PL');
    _tts.setSpeechRate(0.45);
    _tts.setVolume(1.0);
    _tts.setPitch(1.05);
    _tts.setCompletionHandler(() {
      if (_ttsQueue.isNotEmpty) {
        _tts.speak(_ttsQueue.removeAt(0));
      } else {
        if (mounted) setState(() => _isSpeaking = false);
      }
    });
  }

  String _cleanTextForTts(String raw) {
    var text = raw;
    text = text.replaceAll(RegExp(r'<[^>]*>'), ' ');
    text = text.replaceAll(RegExp(r'https?://\S+'), '');
    text = text.replaceAll(RegExp(r'www\.\S+'), '');
    text = text.replaceAll(RegExp(r'Źródło:.*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'fot\.?.*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'photo:.*', caseSensitive: false, multiLine: true), '');
    text = text.replaceAll(RegExp(r'source:.*', caseSensitive: false, multiLine: true), '');
    text = text.replaceAll(RegExp(r'©.*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'Materiał partnera.*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'---.*---', multiLine: true), '');
    text = text.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    text = text.replaceAll(RegExp(r'\(fot\.?\s*\)'), '');
    text = text.replaceAll(RegExp(r'[•■●▪►►▶▷▸▹►]{2,}'), '');
    text = text.replaceAll(RegExp(r'={3,}'), '');
    text = text.replaceAll(RegExp(r'-{3,}'), '');
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  final List<String> _ttsQueue = [];

  Article get _currentArticle {
    final articles = widget.articles;
    if (articles == null || articles.isEmpty) return widget.article;
    return articles[_currentIndex.clamp(0, articles.length - 1)];
  }

  bool get _hasNavigation => widget.articles != null && widget.articles!.length > 1;

  void _recordHistory(Article article) {
    ReadingHistory().add(
      id: article.id,
      title: article.title,
      description: article.description,
      url: article.url,
      imageUrl: article.imageUrl,
      sourceName: article.sourceName,
      publishedAt: article.publishedAt,
    );
  }

  void _cycleFontSize() {
    final settings = context.read<SettingsProvider>();
    final current = settings.readingFontSize;
    final next = current == 14 ? 16 : current == 16 ? 18 : 14;
    settings.setReadingFontSize(next);
  }

  Future<void> _toggleTts() async {
    if (_isSpeaking) {
      await _tts.stop();
      _ttsQueue.clear();
      setState(() => _isSpeaking = false);
      return;
    }
    final article = _currentArticle;
    final hasFull = article.fullContent != null && article.fullContent!.trim().isNotEmpty;
    if (!hasFull) return;
    final raw = article.translatedFullContent ?? article.fullContent!;
    final text = _cleanTextForTts(raw);
    if (text.isEmpty) return;
    _ttsQueue.clear();
    const chunkSize = 3500;
    for (int i = 0; i < text.length; i += chunkSize) {
      _ttsQueue.add(text.substring(i, (i + chunkSize).clamp(0, text.length)));
    }
    setState(() => _isSpeaking = true);
    await _tts.speak(_ttsQueue.removeAt(0));
  }

  bool get _canTts {
    final article = _currentArticle;
    return article.fullContent != null && article.fullContent!.trim().isNotEmpty;
  }

  void _handleSwipeUp() {
    final article = _currentArticle;
    if (article.fullContent != null && article.fullContent!.trim().isNotEmpty) return;
    if (RssService.isGoogleNewsUrl(article.url)) return;
    context.read<NewsProvider>().fetchFullArticleContent(article);
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
    if (_scrollController.hasClients && _scrollController.position.isScrollingNotifier.value) return;
    final dy = event.position.dy - _pointerStartY;
    final dt = DateTime.now().difference(_pointerStartTime!).inMilliseconds;
    if (dt < 700 && dy < -20) {
      _handleSwipeUp();
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _ttsQueue.clear();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _pageController.dispose();
    _tickTimer?.cancel();
    _stopwatch.stop();
    final elapsed = _stopwatch.elapsed.inSeconds;
    _markReadIfEnough(elapsed);
    super.dispose();
  }

  void _markReadIfEnough(int seconds) {
    final article = _currentArticle;
    if (seconds > article.readTimeSeconds) {
      article.readTimeSeconds = seconds;
    }
    if (seconds >= _kReadThresholdSeconds && !article.isRead) {
      context.read<NewsProvider>().markArticleRead(article);
    }
  }

  Article get article => _currentArticle;

  @override
  Widget build(BuildContext context) {
    if (_hasNavigation) {
      return PageView(
        controller: _pageController,
        onPageChanged: (index) {
          _stopwatch.stop();
          _markReadIfEnough(_stopwatch.elapsed.inSeconds);
          setState(() {
            _currentIndex = index;
          });
          _stopwatch.reset();
          _stopwatch.start();
          _recordHistory(_currentArticle);
        },
        children: [
          for (int i = 0; i < widget.articles!.length; i++)
            _buildArticlePage(context, widget.articles![i]),
        ],
      );
    }
    return _buildArticlePage(context, widget.article);
  }

  Widget _buildArticlePage(BuildContext context, Article art) {
    return Scaffold(
      body: Stack(
        children: [
          Listener(
            onPointerDown: _onPointerDown,
            onPointerUp: _onPointerUp,
            child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: art.imageUrl != null
                    ? Hero(
                        tag: 'article-image-${art.id}',
                        child: CachedNetworkImage(imageUrl: art.imageUrl!, fit: BoxFit.cover, cacheManager: AppImageCacheManager.instance),
                      )
                    : Container(color: const Color(0xFF1E2126)),
              ),
              actions: [
                if (art.isRead)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                  ),
                Consumer<NewsProvider>(
                  builder: (context, provider, child) {
                    final hasFullContent = art.fullContent != null && art.fullContent!.trim().isNotEmpty;
                    if (hasFullContent) return const SizedBox.shrink();
                    return IconButton(
                      icon: provider.isFetchingFor(art.id)
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(Icons.download, color: AppTheme.accentFor(context)),
                      onPressed: provider.isFetchingFor(art.id)
                          ? null
                          : () => provider.fetchFullArticleContent(art),
                      tooltip: 'Pobierz treść',
                    );
                  },
                ),
                Consumer<NewsProvider>(
                  builder: (context, provider, child) {
                    final isPolish = provider.isArticlePolish(art);
                    final needsTranslation = !isPolish && (
                      art.translatedTitle == null ||
                      (art.fullContent != null && art.translatedFullContent == null)
                    );
                    if (!needsTranslation) return const SizedBox.shrink();
                    return IconButton(
                      icon: provider.isTranslating
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.translate, color: Colors.blueAccent),
                      onPressed: provider.isTranslating ? null : () => provider.translateArticle(art),
                      tooltip: 'Tłumacz na polski',
                    );
                  },
                ),
                IconButton(
                  icon: Icon(_isSpeaking ? Icons.stop_circle : Icons.volume_up),
                  onPressed: _canTts ? _toggleTts : null,
                  tooltip: _canTts ? (_isSpeaking ? 'Zatrzymaj' : 'Czytaj artykuł') : 'Pobierz artykuł, żeby odtworzyć',
                  color: _canTts ? Colors.red : Colors.grey,
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_browser),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ArticleWebViewScreen(url: art.url, title: art.title),
                    ));
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    switch (value) {
                      case 'font':
                        _cycleFontSize();
                        break;
                      case 'share':
                        SharePlus.instance.share(ShareParams(text: '${art.title}\n\n${art.url}'));
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'font', child: Text('Rozmiar czcionki')),
                    const PopupMenuItem(value: 'share', child: Text('Udostępnij')),
                  ],
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
                        Flexible(
                          child: Text(
                            art.sourceName.toUpperCase(),
                            style: TextStyle(
                              color: AppTheme.accentFor(context),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('dd.MM.yyyy HH:mm').format(art.publishedAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      art.translatedTitle ?? art.title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(height: 1.2),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    Consumer<NewsProvider>(
                      builder: (context, provider, child) {
                        return _buildContentBody(context, provider, art);
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

      _buildFloatingReactionButtons(context, art),
    ],
  ),
);
  }

  Widget _buildContentBody(BuildContext context, NewsProvider provider, Article art) {
    final hasFullContent = art.fullContent != null && art.fullContent!.trim().isNotEmpty;
    final isFetching = provider.isFetchingFor(art.id);
    final fetchFailed = provider.fetchFailedIds.contains(art.id);

    if (isFetching) {
      return Column(
        key: const ValueKey('loading'),
        children: [
          if (!hasFullContent)
            HtmlWidget(
              art.translatedDescription ?? (art.description.isNotEmpty ? art.description : ''),
              textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: context.read<SettingsProvider>().readingFontSize.toDouble(), height: 1.6),
              onTapUrl: (url) async { await _launchUrl(context, url); return true; },
            ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            'Sowa pobiera artykuł...',
            style: TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      );
    }

    if (hasFullContent) {
      return Column(
        key: const ValueKey('full'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HtmlWidget(
            art.translatedFullContent ?? art.fullContent!,
            textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: context.read<SettingsProvider>().readingFontSize.toDouble(), height: 1.6),
            onTapUrl: (url) async { await _launchUrl(context, url); return true; },
          ),
        ],
      );
    }

    return Column(
      key: const ValueKey('snippet'),
      children: [
        HtmlWidget(
          art.translatedDescription ?? (art.description.isNotEmpty ? art.description : 'Brak treści artykułu.'),
          textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: context.read<SettingsProvider>().readingFontSize.toDouble(), height: 1.6),
          onTapUrl: (url) async { await _launchUrl(context, url); return true; },
        ),
        const SizedBox(height: 24),
        if (fetchFailed) ...[
          Icon(Icons.error_outline, color: Colors.red.shade300, size: 32),
          const SizedBox(height: 8),
          Text(
            'Nie udało się pobrać treści',
            style: TextStyle(color: Colors.red.shade300, fontSize: 13),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => provider.fetchFullArticleContent(art),
            icon: Icon(Icons.download, size: 18, color: AppTheme.accentFor(context)),
            label: Text(
              fetchFailed ? 'SPRÓBUJ PONOWNIE' : 'POBIERZ TREŚĆ',
              style: TextStyle(fontSize: 12, color: AppTheme.accentFor(context)),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accentFor(context),
              side: BorderSide(color: AppTheme.accentFor(context).withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ArticleWebViewScreen(url: art.url, title: art.title),
              ));
            },
            icon: Icon(Icons.open_in_browser, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            label: Text(
              'OTWÓRZ W PRZEGLĄDARCE',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildFloatingReactionButtons(BuildContext context, Article art) {
    final provider = context.read<NewsProvider>();
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => provider.toggleLike(art),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: art.isLiked ? AppTheme.accentFor(context) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    art.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    color: art.isLiked ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => provider.toggleDislike(art),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: art.isDisliked ? Colors.red : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    art.isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                    color: art.isDisliked ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () async {
                  if (!art.isSaved) {
                    await provider.toggleSaved(art);
                    if (context.mounted) {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (_) => TagPickerBottomSheet(article: art),
                      );
                    }
                  } else {
                    await provider.toggleSaved(art);
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: art.isSaved ? Colors.blue : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    art.isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: art.isSaved ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
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
