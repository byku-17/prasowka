import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart' show PointerDeviceKind, VelocityTracker;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/services/reader_service.dart';
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

  @visibleForTesting
  static List<String> debugSpeechChunks(String text) => _ArticleDetailScreenState._buildSpeechChunks(text);
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late final Stopwatch _stopwatch;
  final ScrollController _scrollController = ScrollController();
  late int _currentIndex;
  late final PageController _pageController;

  double _pointerStartY = 0;
  DateTime? _pointerStartTime;
  double? _pointerStartScrollOffset;
  final VelocityTracker _pointerVelocityTracker =
      VelocityTracker.withKind(PointerDeviceKind.touch);

  // Per-artykułowy cache treści — każdy artykuł w PageView ma własne
  // chunksy, "firstTextChunk" i postęp odsłaniania (bez współdzielenia
  // stanu między stronami).
  final Map<String, _ArticleContentState> _contentCache = {};
  static const int _contentCacheLimit = 20;

  void _openInBrowser(Article art) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ArticleWebViewScreen(url: art.url, title: art.title),
    ));
  }

  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex ?? 0;
    _pageController = PageController(initialPage: _currentIndex);
    _stopwatch = Stopwatch()..start();
    _scrollController.addListener(_scrollListener);
    _initTts();
    _recordHistory(widget.article);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeAutoFetch(_currentArticle);
    });
  }

  void _maybeAutoFetch(Article art) {
    if (_hasUsableContent(art)) return;
    if (RssService.isGoogleNewsUrl(art.url)) return;
    final provider = context.read<NewsProvider>();
    if (provider.isFetchingFor(art.id)) return;
    provider.fetchFullArticleContent(art);
  }

  void _initTts() {
    _tts.setLanguage('pl-PL');
    _tts.setSpeechRate(0.45);
    _tts.setVolume(1.0);
    _tts.setPitch(1.05);
    _tts.setCompletionHandler(() {
      if (!_isSpeaking) return;
      if (_ttsQueue.isNotEmpty) {
        _speakChunk(_ttsQueue.removeAt(0));
      } else {
        _ttsCurrentText = null;
        _ttsChunkOffset = 0;
        if (mounted) setState(() => _isSpeaking = false);
      }
    });
    // Android: onRangeStart co słowo. Dzięki temu pauza może wznowić
    // od końca ostatnio odtworzonego słowa, a nie od początku fragmentu.
    // Używamy `end` (a nie `start`), żeby wznawianie NIE powtarzało
    // ostatniego słowa przed pauzą.
    _tts.setProgressHandler((text, start, end, word) {
      if (_isSpeaking && text == _ttsCurrentText) {
        _ttsChunkOffset = end > start ? end : start;
      }
    });
  }

  final List<String> _ttsQueue = [];

  /// Tekst aktualnie odtwarzany przez lektora (może być resztą
  /// fragmentu po wznowieniu).
  String? _ttsCurrentText;

  /// Pozycja (offset znaków) w [_ttsCurrentText], do której dotarł lektor.
  int _ttsChunkOffset = 0;

  /// Odtwarza tekst i zapamiętuje go jako bieżący, żeby pauza mogła
  /// wznowić dokładnie od tej pozycji.
  Future<void> _speakChunk(String text) async {
    _ttsCurrentText = text;
    _ttsChunkOffset = 0;
    await _tts.speak(text);
  }

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
      // Pauza: zatrzymaj lektora, ale zachowaj bieżący tekst i pozycję
      // (word-level przez setProgressHandler). Kolejka pozostaje nietknięta.
      setState(() => _isSpeaking = false);
      await _tts.stop();
      return;
    }
    final article = _currentArticle;
    if (!_hasUsableContent(article)) return;
    if (_ttsCurrentText != null) {
      // Wznów od zapamiętanej pozycji w bieżącym tekście.
      final current = _ttsCurrentText!;
      final offset = _ttsChunkOffset.clamp(0, current.length);
      final remainder = current.substring(offset).trim();
      if (remainder.isEmpty) {
        // Bieżący tekst był już dograny do końca — przejdź do następnego
        // fragmentu albo zakończ czytanie.
        _ttsCurrentText = null;
        _ttsChunkOffset = 0;
        if (_ttsQueue.isEmpty) {
          setState(() => _isSpeaking = false);
          return;
        }
        setState(() => _isSpeaking = true);
        _speakChunk(_ttsQueue.removeAt(0));
      } else {
        setState(() => _isSpeaking = true);
        await _speakChunk(remainder);
      }
      return;
    }
    if (_ttsQueue.isEmpty) {
      final raw = article.translatedFullContent ?? article.fullContent!;
      final text = cleanForTts(raw);
      if (text.isEmpty) return;
      _ttsQueue.addAll(_buildSpeechChunks(text));
    }
    setState(() => _isSpeaking = true);
    await _speakChunk(_ttsQueue.removeAt(0));
  }

  /// Dzieli tekst lektora na zdania (każde zdanie = osobny kawałek), żeby
  /// wznawianie po pauzie cofało się tylko o jedno zdanie, a nie o cały
  /// fragment 3500 znaków. Długie zdania (powyżej [maxSentenceChars])
  /// są dodatkowo pocięte, by lektor nie czytał ich w nieskończoność.
  static List<String> _buildSpeechChunks(String text, {int maxSentenceChars = 600}) {
    final chunks = <String>[];
    final current = StringBuffer();
    void flush() {
      final s = current.toString().trim();
      current.clear();
      if (s.isEmpty) return;
      if (s.length <= maxSentenceChars) {
        chunks.add(s);
        return;
      }
      for (int i = 0; i < s.length; i += maxSentenceChars) {
        final part = s.substring(i, (i + maxSentenceChars).clamp(0, s.length)).trim();
        if (part.isNotEmpty) chunks.add(part);
      }
    }
    for (int i = 0; i < text.length; i++) {
      final c = text[i];
      current.write(c);
      final isTerminal = c == '!' || c == '?' || c == '\n';
      final isDotTerminal = c == '.' &&
          (i + 1 >= text.length || (text[i + 1] == ' ' && _isSentenceStart(text, i + 2)));
      if (isTerminal || isDotTerminal) flush();
    }
    flush();
    return chunks;
  }

  static bool _isSentenceStart(String text, int index) {
    if (index >= text.length) return true;
    return RegExp(r'[A-ZĄĆĘŁŃÓŚŹŻ0-9„"\u2026]').hasMatch(text[index]);
  }

  bool get _canTts {
    return _hasUsableContent(_currentArticle);
  }

  void _handleSwipeUp() {
    final article = _currentArticle;
    if (RssService.isGoogleNewsUrl(article.url)) {
      _showSwipeFeedback('Link Google News — treść dostępna tylko w zewnętrznej przeglądarce.');
      return;
    }
    if (_hasUsableContent(article)) {
      _showSwipeFeedback('Treść artykułu jest już załadowana.');
      return;
    }
    final provider = context.read<NewsProvider>();
    if (provider.isFetchingFor(article.id)) {
      _showSwipeFeedback('Treść jest już pobierana...');
      return;
    }
    provider.fetchFullArticleContent(article);
    _showSwipeFeedback('Pobieram treść artykułu...');
  }

  void _handleSwipeDown() {
    final article = _currentArticle;
    if (RssService.isGoogleNewsUrl(article.url)) {
      _showSwipeFeedback('Link Google News — pobranie treści niedostępne.');
      return;
    }
    final provider = context.read<NewsProvider>();
    if (provider.isFetchingFor(article.id)) {
      _showSwipeFeedback('Pobieranie już trwa...');
      return;
    }
    provider.fetchFullArticleContent(article);
    _showSwipeFeedback('Odświeżam / pobieram treść...');
  }

  void _showSwipeFeedback(String message) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _scrollListener() {
    final pixels = _scrollController.position.pixels;
    final maxScroll = _scrollController.position.maxScrollExtent;

    if (pixels >= maxScroll - 100) {
      final current = _currentArticle;
      if (!current.isRead) {
        context.read<NewsProvider>().markArticleRead(current);
      }
    }

    final state = _contentCache[_currentArticle.id];
    if (state != null && state.revealed.value < state.chunks.length) {
      if (pixels >= maxScroll - 150) {
        state.revealed.value++;
      }
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerStartY = event.position.dy;
    _pointerStartTime = DateTime.now();
    _pointerStartScrollOffset = _scrollController.hasClients
        ? _scrollController.position.pixels
        : null;
    _pointerVelocityTracker.addPosition(event.timeStamp, event.position);
  }

  void _onPointerMove(PointerMoveEvent event) {
    _pointerVelocityTracker.addPosition(event.timeStamp, event.position);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_pointerStartTime == null) return;
    _pointerVelocityTracker.addPosition(event.timeStamp, event.position);
    final velocityEstimate = _pointerVelocityTracker.getVelocityEstimate();

    final dy = event.position.dy - _pointerStartY;
    final dt = DateTime.now().difference(_pointerStartTime!).inMilliseconds;
    _pointerStartTime = null;
    if (dt > 700) return;

    // Swipe wymaga szybkiego, gwałtownego ruchu. Wolne przewijanie przy
    // czytaniu (nawet o dużej amplitudzie) nie jest swipe'em.
    final velocityY = velocityEstimate?.pixelsPerSecond.dy ?? 0;

    // Jeśli w trakcie gestu treść faktycznie się przewinęła, to było
    // czytanie, a nie swipe.
    final startOffset = _pointerStartScrollOffset;
    final currentOffset = _scrollController.hasClients
        ? _scrollController.position.pixels
        : null;
    _pointerStartScrollOffset = null;
    if (startOffset != null &&
        currentOffset != null &&
        (currentOffset - startOffset).abs() > 30) {
      return;
    }

    const minSwipeVelocity = 350.0;
    final pos = _scrollController.hasClients ? _scrollController.position : null;
    if (dy < -40 && velocityY < -minSwipeVelocity) {
      _handleSwipeUp();
    } else if (dy > 40 && velocityY > minSwipeVelocity) {
      if (pos == null || pos.pixels <= 1) {
        _handleSwipeDown();
      }
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _ttsQueue.clear();
    _ttsCurrentText = null;
    _ttsChunkOffset = 0;
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _pageController.dispose();
    for (final state in _contentCache.values) {
      state.dispose();
    }
    _contentCache.clear();
    _stopwatch.stop();
    final elapsed = _stopwatch.elapsed.inSeconds;
    // Pobierz referencję PRZED dispose — context.read po dispose jest
    // bezpieczny (nie rejestruje zależności), ale notifyListeners może
    // wywołać rebuild drzewa. Dlatego使用.safe pattern.
    final provider = context.read<NewsProvider>();
    _markReadIfEnough(elapsed, provider);
    super.dispose();
  }

  void _markReadIfEnough(int seconds, NewsProvider provider) {
    final article = _currentArticle;
    if (seconds > article.readTimeSeconds) {
      article.readTimeSeconds = seconds;
    }
    if (seconds >= _kReadThresholdSeconds && !article.isRead) {
      provider.markArticleRead(article);
    }
  }

  Article get article => _currentArticle;

  @override
  Widget build(BuildContext context) {
    if (_hasNavigation) {
      return PageView.builder(
        controller: _pageController,
        physics: const _CalmPageScrollPhysics(),
        itemCount: widget.articles!.length,
        onPageChanged: (index) {
          _stopwatch.stop();
          _markReadIfEnough(_stopwatch.elapsed.inSeconds, context.read<NewsProvider>());
          // Zmiana artykułu przerywa czytanie lektora (także po pauzie).
          _tts.stop();
          _ttsQueue.clear();
          _ttsCurrentText = null;
          _ttsChunkOffset = 0;
          setState(() {
            _currentIndex = index;
            _isSpeaking = false;
          });
          // Pobierz treść nowego artykułu, żeby TTS stał się dostępny.
          _maybeAutoFetch(_currentArticle);
          _stopwatch.reset();
          _stopwatch.start();
          _recordHistory(_currentArticle);
        },
        itemBuilder: (context, i) => _buildArticlePage(context, widget.articles![i]),
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
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: context.read<SettingsProvider>().showImagesNow && art.imageUrl != null
                    ? Hero(
                        tag: 'article-image-${art.id}',
                        child: CachedNetworkImage(imageUrl: art.imageUrl!, fit: BoxFit.cover, cacheManager: AppImageCacheManager.instance),
                      )
                    : Container(color: const Color(0xFF1E2126)),
              ),
              actions: [
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
                  icon: Icon(_isSpeaking ? Icons.pause_circle_filled : Icons.play_circle_outline),
                  onPressed: _canTts ? _toggleTts : null,
                  tooltip: _canTts
                      ? (_isSpeaking
                          ? 'Pauza'
                          : (_ttsQueue.isNotEmpty || _ttsCurrentText != null)
                              ? 'Wznów'
                              : 'Czytaj artykuł')
                      : 'Pobierz artykuł, żeby odtworzyć',
                  color: _canTts ? Colors.red : Colors.grey,
                ),
                IconButton(
                  icon: const Icon(Icons.text_fields),
                  onPressed: _cycleFontSize,
                  tooltip: 'Rozmiar czcionki',
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () => SharePlus.instance.share(ShareParams(text: '${art.title}\n\n${art.url}')),
                  tooltip: 'Udostępnij',
                ),
                // Pulsuje zawsze, gdy pełna treść nie jest jeszcze
                // dostępna — zarówno przy błędzie, jak i przy braku
                // załadowania artykułu.
                _PulsingBrowserButton(
                  article: art,
                  pulse: !_hasUsableContent(art),
                  onPressed: () => _openInBrowser(art),
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
                      style: _readingFontStyle(context, Theme.of(context).textTheme.headlineMedium?.copyWith(height: 1.2)),
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

  bool _hasUsableContent(Article art) {
    final fc = art.fullContent;
    if (fc == null) return false;
    // Zwiększono próg do 350 znaków dla spójności z NewsProvider
    return fc.trim().length >= 350;
  }

  _ArticleContentState _chunksFor(Article art) {
    final content = art.translatedFullContent ?? art.fullContent;
    if (content == null) return _ArticleContentState(key: '${art.id}|0', chunks: const [], firstTextChunk: '');
    final key = '${art.id}|${content.length}';
    final existing = _contentCache[art.id];
    if (existing != null && existing.key == key) return existing;
    final chunks = _splitContentIntoChunks(content);
    // Próbką porównania jest pierwszy chunk z rzeczywistym tekstem
    // (początek treści może być np. <figure> albo pustym kontenerem).
    final firstTextChunk = chunks.firstWhere(
      (c) => ReaderService.textContent(c).trim().isNotEmpty,
      orElse: () => content,
    );
    final state = _ArticleContentState(key: key, chunks: chunks, firstTextChunk: firstTextChunk);
    state.revealed.value = math.min(1, chunks.length);
    _contentCache[art.id] = state;
    if (_contentCache.length > _contentCacheLimit) {
      final removed = _contentCache.remove(_contentCache.keys.first);
      removed?.dispose();
    }
    return state;
  }

  static List<String> _splitContentIntoChunks(String html, {int chunkCount = 5}) {
    if (html.trim().isEmpty) return [html];
    final normalized = ReaderService.normalizeHtml(html);
    final parts = normalized.split(RegExp(r'(?=</(?:p|h[1-6]|li|blockquote|div|figure)>)'));
    if (parts.length <= chunkCount) return parts;
    final targetLen = (normalized.length / chunkCount).ceil();
    final chunks = <String>[];
    final buf = StringBuffer();
    for (final part in parts) {
      if (buf.isNotEmpty && buf.length + part.length >= targetLen) {
        chunks.add(buf.toString());
        buf.clear();
      }
      buf.write(part);
    }
    if (buf.isNotEmpty) chunks.add(buf.toString());
    return chunks;
  }

  TextStyle? _readingFontStyle(BuildContext context, TextStyle? base) {
    final font = context.read<SettingsProvider>().readingFont;
    if (font == SettingsProvider.readingFontSerif) return GoogleFonts.merriweather(textStyle: base);
    if (font == SettingsProvider.readingFontSans) return GoogleFonts.lato(textStyle: base);
    return base;
  }

  Widget _buildContentBody(BuildContext context, NewsProvider provider, Article art) {
    final hasFullContent = _hasUsableContent(art);
    final isFetching = provider.isFetchingFor(art.id);
    final fetchFailed = provider.fetchFailedIds.contains(art.id);

    final settings = context.read<SettingsProvider>();
    final textStyle = _readingFontStyle(context, Theme.of(context).textTheme.bodyLarge?.copyWith(
      fontSize: settings.readingFontSize.toDouble(),
      height: 1.6,
    ));

    final Widget description = HtmlWidget(
      art.translatedDescription ?? (art.description.isNotEmpty ? art.description : ''),
      textStyle: textStyle,
      onTapUrl: (url) async { await _launchUrl(context, url); return true; },
    );

    if (hasFullContent) {
      final state = _chunksFor(art);
      final chunks = state.chunks;

      // Wykryj przypadek, gdy ekstrakcja dała technicznie niepustą treść,
      // ale bez czytelnego tekstu (portal zmienił układ, CSS/JS w treści itp.).
      if (chunks.isEmpty || (chunks.length == 1 && ReaderService.textContent(chunks.first).trim().length < 80)) {
        return Column(
          key: const ValueKey('extraction-failed'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            description,
            const SizedBox(height: 24),
            Text(
              'Sowa nie mogła wyciągnąć pełnej treści artykułu.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 12),
            _PulsingBrowserButton(
              article: art,
              pulse: true,
              onPressed: () => _openInBrowser(art),
            ),
          ],
        );
      }

      final showLead = !ReaderService.isLeadDuplicated(
        art.translatedDescription ?? art.description,
        state.firstTextChunk,
      );
      return ValueListenableBuilder<int>(
        valueListenable: state.revealed,
        builder: (context, revealedValue, _) {
          final visible = revealedValue.clamp(1, chunks.length);
          return Column(
            key: const ValueKey('progressive'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showLead) ...[
                description,
                const SizedBox(height: 16),
              ],
              for (int i = 0; i < visible; i++) ...[
                HtmlWidget(
                  chunks[i],
                  key: ValueKey('chunk_$i'),
                  textStyle: textStyle,
                  onTapUrl: (url) async { await _launchUrl(context, url); return true; },
                ),
                if (i < visible - 1) const SizedBox(height: 12),
              ],
              if (visible < chunks.length) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Text(
                      'Sowa doładowuje treść...',
                      style: TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      );
    }

    if (isFetching) {
      return Column(
        key: const ValueKey('loading'),
        children: [
          description,
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            'Sowa pobiera artykuł...',
            style: TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
        ],
      );
    }

    return Column(
      key: const ValueKey('snippet'),
      children: [
        description,
        const SizedBox(height: 24),
        if (fetchFailed) ...[
          GestureDetector(
            onTap: () => _openInBrowser(art),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade300, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Błąd pobierania, otwórz w zewnętrznej przeglądarce.',
                    style: TextStyle(color: Colors.red.shade300, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.swipe_up, size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Treść załaduje się podczas czytania.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
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
                onTap: () {
                  if (!art.isSaved) {
                    provider.toggleSaved(art);
                  }
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (_) => TagPickerBottomSheet(article: art),
                  );
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

class _CalmPageScrollPhysics extends PageScrollPhysics {
  const _CalmPageScrollPhysics({super.parent});

  // Lekki dotyk / przypadkowy ruch nie rozpoczyna przeciągania —
  // palec musi najpierw pokonać próg dystansu.
  @override
  double get dragStartDistanceMotionThreshold => 15.0;

  // Zmniejsza czułość przeciągnięcia — trzeba pociągnąć dalej,
  // zanim strona zacznie się przesuwać.
  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    return offset * 0.3;
  }

  // Wymaga wyraźnego flingu do zmiany strony.
  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if (velocity.abs() < minFlingVelocity * 2.5) {
      return super.createBallisticSimulation(position, 0);
    }
    return super.createBallisticSimulation(position, velocity);
  }

  @override
  _CalmPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _CalmPageScrollPhysics(parent: buildParent(ancestor));
  }
}

// Przycisk "otwórz w przeglądarce" w pasku górnym — pulsuje (skala +
// kolor) tylko wtedy, gdy pobranie artykułu nie powiodło się i widoczny
// jest komunikat o błędzie.
class _PulsingBrowserButton extends StatefulWidget {
  final Article article;
  final VoidCallback onPressed;
  final bool pulse;

  const _PulsingBrowserButton({
    required this.article,
    required this.onPressed,
    required this.pulse,
  });

  @override
  State<_PulsingBrowserButton> createState() => _PulsingBrowserButtonState();
}

class _PulsingBrowserButtonState extends State<_PulsingBrowserButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    if (widget.pulse) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulsingBrowserButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulse && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Przy powiększaniu ikonka zmienia kolor na czerwony.
        final color = widget.pulse
            ? Color.lerp(Colors.white, Colors.red, _animation.value)!
            : Colors.white;
        final scale = widget.pulse ? 1.0 + 0.25 * _animation.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: IconButton(
            icon: Icon(Icons.open_in_browser, color: color),
            onPressed: widget.onPressed,
          ),
        );
      },
    );
  }
}

/// Cache treści pojedynczego artykułu (chunksy + próbka leadu + postęp
/// odsłaniania). Trzymane per artykuł, nie współdzielone między stronami.
class _ArticleContentState {
  _ArticleContentState({
    required this.key,
    required this.chunks,
    required this.firstTextChunk,
  }) : revealed = ValueNotifier<int>(0);

  /// Klucz wersji treści (id + długość) — pozwala wykryć zmianę treści
  /// (np. po tłumaczeniu) bez kosztownego porównywania stringów.
  final String key;
  final List<String> chunks;
  final String firstTextChunk;
  final ValueNotifier<int> revealed;

  void dispose() => revealed.dispose();
}
