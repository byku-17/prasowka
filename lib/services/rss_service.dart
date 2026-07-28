import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dart_rss/dart_rss.dart';
import 'package:html/parser.dart';
import 'package:intl/intl.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/models/news_source.dart';
import 'package:flutter/foundation.dart';

class RssService {
  static final _htmlTagRegExp = RegExp(r'<[^>]*>', caseSensitive: false);
  static final _htmlBannedTagsRegExp = RegExp(r'<(source|picture|script|style|zrodlo|figure|figcaption)[^>]*>.*?</\1>', caseSensitive: false);
  static final _whitespaceRegExp = RegExp(r'\s+');

  static final _socialDomains = RegExp(
    r'pbs\.twimg\.com|abs\.twimg\.com|platform\.twitter\.com|'
    r'graph\.facebook\.com|fbcdn\.net|lookaside\.fbsbx\.com|'
    r'i\.ytimg\.com|cdn\.instagram\.com',
    caseSensitive: false,
  );

  static final _socialImgTagRegExp = RegExp(
    r'<img[^>]*(pbs\.twimg\.com|fbcdn\.net|ytimg\.com|lookaside\.fbsbx\.com|cdn\.instagram\.com)[^>]*/?>',
    caseSensitive: false,
  );
  static final _trackingPixelRegExp = RegExp(
    r'<img[^>]*(width=.1[^0-9]|height=.1[^0-9]|width=.2[^0-9]|height=.2[^0-9])[^>]*/?>',
    caseSensitive: false,
  );
  static final _socialShareTextRegExp = RegExp(
    r'(Zrodlo|Źrodlo|Source|source):\s*(Twitter|Facebook|Instagram|YouTube|X\.com)[^.]*\.?',
    caseSensitive: false,
  );

  Future<List<Article>> fetchArticles(NewsSource source) async {
    final url = source.rssUrl.trim();
    try {
      final uri = Uri.parse(url);
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'application/rss+xml, application/xml, text/xml, */*',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        String xml;
        try {
          xml = utf8.decode(response.bodyBytes, allowMalformed: true);
        } catch (_) {
          xml = latin1.decode(response.bodyBytes);
        }
        
        final trimmedXml = xml.trim();
        final List<Article> articles = [];

        try {
          if (trimmedXml.contains('<rss') || trimmedXml.contains('<channel')) {
            final feed = RssFeed.parse(trimmedXml);
            for (var item in feed.items) {
              final title = (item.title ?? 'Bez tytułu').trim();
              final cleanDesc = _cleanHtml(item.description ?? '');
              final rawUrl = item.link ?? '';
              final contentValue = item.content?.value;
              final realUrl = extractRealUrlFromContent(contentValue) ?? rawUrl;
              articles.add(Article(
                id: item.guid ?? (rawUrl.isNotEmpty ? rawUrl : null) ?? DateTime.now().toIso8601String(),
                title: title,
                description: cleanDesc.isNotEmpty ? cleanDesc : 'Artykuł ze źródła: ${source.name}',
                content: contentValue ?? item.description ?? '',
                url: realUrl,
                publishedAt: _parseDate(item.pubDate),
                sourceName: source.name,
                imageUrl: _getImg(item),
              ));
            }
          } else {
            final feed = AtomFeed.parse(trimmedXml);
            for (var item in feed.items) {
              final title = (item.title ?? 'Bez tytułu').trim();
              final cleanDesc = _cleanHtml(item.summary ?? '');
              final rawUrl = item.links.isNotEmpty ? item.links.first.href ?? '' : '';
              final contentValue = item.content;
              final realUrl = extractRealUrlFromContent(contentValue) ?? rawUrl;
              articles.add(Article(
                id: item.id ?? (rawUrl.isNotEmpty ? rawUrl : null) ?? DateTime.now().toIso8601String(),
                title: title,
                description: cleanDesc.isNotEmpty ? cleanDesc : 'Artykuł ze źródła: ${source.name}',
                content: contentValue ?? item.summary ?? '',
                url: realUrl,
                publishedAt: _parseDate(item.updated ?? item.published),
                sourceName: source.name,
                imageUrl: _getAtomImg(item),
              ));
            }
          }
          return articles;
        } catch (e) {
          debugPrint('Sowa RssService: Błąd parsowania ${source.name}: $e');
          return [];
        }
      }
    } catch (e) {
      debugPrint('Sowa RssService: Błąd sieci ${source.name}: $e');
    }
    return [];
  }

  String _cleanHtml(String htmlString) {
    if (htmlString.isEmpty) return '';
    if (!htmlString.contains('<')) {
      return htmlString.replaceAll(_socialShareTextRegExp, '').replaceAll(_whitespaceRegExp, ' ').trim();
    }
    try {
      String cleaned = htmlString.replaceAll(_htmlBannedTagsRegExp, '');
      cleaned = cleaned.replaceAll(_trackingPixelRegExp, '');
      cleaned = cleaned.replaceAll(_socialImgTagRegExp, '');
      cleaned = cleaned.replaceAll(_htmlTagRegExp, ' ');
      cleaned = cleaned.replaceAll(_socialShareTextRegExp, '');
      return cleaned.replaceAll(_whitespaceRegExp, ' ').trim();
    } catch (_) {
      return htmlString.trim();
    }
  }

  String? _getImg(RssItem item) {
    try {
      if (item.media?.contents != null && item.media!.contents.isNotEmpty) {
        final url = item.media!.contents.first.url;
        if (url != null && _isValidImageUrl(url)) return url;
      }
      if (item.media?.thumbnails != null && item.media!.thumbnails.isNotEmpty) {
        final url = item.media!.thumbnails.first.url;
        if (url != null && _isValidImageUrl(url)) return url;
      }
    } catch (_) {}
    
    final enclosureUrl = item.enclosure?.url;
    if (enclosureUrl != null && _isValidImageUrl(enclosureUrl)) return enclosureUrl;
    
    final itunesImage = item.itunes?.image?.href;
    if (itunesImage != null && _isValidImageUrl(itunesImage)) return itunesImage;

    final htmlContent = item.content?.value ?? item.description ?? '';
    if (htmlContent.contains('<img')) {
      try {
        final doc = parse(htmlContent);
        final src = doc.querySelector('img')?.attributes['src'];
        if (src != null && _isValidImageUrl(src)) return src;
      } catch (_) {}
    }
    return null;
  }

  String? _getAtomImg(AtomItem item) {
    try {
      for (var link in item.links) {
        if (link.href != null && _isValidImageUrl(link.href!)) return link.href;
      }
    } catch (_) {}
    final source = item.content ?? item.summary ?? '';
    if (source.contains('<img')) {
      try {
        final document = parse(source);
        final src = document.querySelector('img')?.attributes['src'];
        if (src != null && _isValidImageUrl(src)) return src;
      } catch (_) {}
    }
    return null;
  }

  bool _isValidImageUrl(String url) {
    final u = url.toLowerCase();
    if (_socialDomains.hasMatch(u)) return false;
    
    // Sprawdzamy standardowe rozszerzenia
    if (u.contains('.jpg') || u.contains('.jpeg') || u.contains('.png') || 
        u.contains('.webp') || u.contains('.gif')) {
      return true;
    }
    
    // Obsługa dynamicznych URL-i (np. image.php?id=...)
    if (u.contains('image') || u.contains('img') || u.contains('photo')) {
      // Jeśli URL zawiera parametry zapytania (?), uznajemy go za potencjalny obrazek,
      // jeśli występuje w nim słowo kluczowe związane z grafiką
      if (u.contains('?')) return true;
    }
    
    return false;
  }

  DateTime _parseDate(String? dateValue) {
    if (dateValue == null || dateValue.isEmpty) return DateTime.now();
    try {
      return DateTime.parse(dateValue);
    } catch (_) {
      try {
        final format = DateFormat("EEE, dd MMM yyyy HH:mm:ss Z", 'en_US');
        return format.parse(dateValue);
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  /// Wyszukuje artykuły w Google News RSS
  Future<List<Article>> searchGoogleNews(String query) async {
    if (query.trim().isEmpty) return [];
    final url = 'https://news.google.com/rss/search?q=${Uri.encodeComponent(query)}&hl=pl&gl=PL&ceid=PL:pl';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'application/rss+xml, application/xml, text/xml, */*',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final xml = utf8.decode(response.bodyBytes, allowMalformed: true);
        final feed = RssFeed.parse(xml.trim());
        return feed.items.map((item) {
          final title = (item.title ?? 'Bez tytułu').trim();
          final cleanDesc = _cleanHtml(item.description ?? '');
          final sourceName = _extractSource(title);
          final rawUrl = item.link ?? '';
          final contentValue = item.content?.value;
          final realUrl = extractRealUrlFromContent(contentValue) ?? rawUrl;
          return Article(
            id: 'search_${item.guid ?? (rawUrl.isNotEmpty ? rawUrl : null) ?? DateTime.now().toIso8601String()}',
            title: title,
            description: cleanDesc.isNotEmpty ? cleanDesc : 'Artykuł ze źródła: $sourceName',
            content: contentValue ?? item.description ?? '',
            url: realUrl,
            publishedAt: _parseDate(item.pubDate),
            sourceName: sourceName,
            imageUrl: _getImg(item),
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Sowa Search: Błąd Google News RSS: $e');
    }
    return [];
  }

  /// Wyciąga nazwę źródła z tytułu Google News (np. "Tytuł - TVN24" → "TVN24")
  String _extractSource(String title) {
    final dashIdx = title.lastIndexOf(' - ');
    if (dashIdx > 0) return title.substring(dashIdx + 3).trim();
    return 'Google News';
  }

  /// Wyodrębnia prawdziwy URL artykułu z pola content RSS Google News.
  /// Google News RSS zwraca content w formacie: <a href="PRAWDZIWI_URL">...</a>
  /// Zwraca null jeśli nie udało się wyodrębnić (wtedy pokazujemy "Otwórz w przeglądarce")
  static String? extractRealUrlFromContent(String? contentValue) {
    if (contentValue == null || contentValue.isEmpty) return null;
    try {
      final doc = parse(contentValue);
      final links = doc.querySelectorAll('a[href]');
      for (final link in links) {
        final href = link.attributes['href'];
        if (href == null || href.isEmpty) continue;
        // Pomijamy linki do Google News
        if (href.contains('news.google.com')) continue;
        // Akceptujemy tylko http/https
        if (href.startsWith('http://') || href.startsWith('https://')) {
          return href;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Sprawdza czy URL pochodzi z Google News (prawdziwy URL nie został wyodrębniony)
  static bool isGoogleNewsUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.contains('news.google.com');
  }
}
