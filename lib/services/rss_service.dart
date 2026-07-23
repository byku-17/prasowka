import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dart_rss/dart_rss.dart';
import 'package:html/parser.dart';
import 'package:intl/intl.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/models/news_source.dart';
import 'package:flutter/foundation.dart';

class RssService {
  /// Pobiera i parsuje artykuły w sposób zoptymalizowany pod wydajność mobilną
  Future<List<Article>> fetchArticles(NewsSource source) async {
    final url = source.rssUrl.trim();
    
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'application/rss+xml, application/xml, text/xml, */*',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 10)); // Skrócony timeout dla płynności

      if (response.statusCode == 200) {
        // Dekodujemy body
        String xml;
        try {
          xml = utf8.decode(response.bodyBytes, allowMalformed: true);
        } catch (_) {
          xml = latin1.decode(response.bodyBytes);
        }
        
        final trimmedXml = xml.trim();
        final List<Article> articles = [];

        // Parsowanie (bez Isolate dla małych paczek - mniejszy narzut na procesor)
        try {
          if (trimmedXml.contains('<rss') || trimmedXml.contains('<channel')) {
            final feed = RssFeed.parse(trimmedXml);
            for (var item in feed.items) {
              articles.add(Article(
                id: item.guid ?? item.link ?? DateTime.now().toIso8601String(),
                title: (item.title ?? 'Bez tytułu').trim(),
                description: _cleanHtml(item.description ?? ''),
                content: item.content?.value ?? item.description ?? '',
                url: item.link ?? '',
                publishedAt: _parseDate(item.pubDate),
                sourceName: source.name,
                imageUrl: _getImg(item),
              ));
            }
          } else {
            final feed = AtomFeed.parse(trimmedXml);
            for (var item in feed.items) {
              articles.add(Article(
                id: item.id ?? (item.links.isNotEmpty ? item.links.first.href : null) ?? DateTime.now().toIso8601String(),
                title: (item.title ?? 'Bez tytułu').trim(),
                description: _cleanHtml(item.summary ?? ''),
                content: item.content ?? item.summary ?? '',
                url: item.links.isNotEmpty ? item.links.first.href ?? '' : '',
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
      } else {
        return [];
      }
    } catch (e) {
      return []; 
    }
  }

  String _cleanHtml(String htmlString) {
    if (htmlString.isEmpty) return '';
    if (!htmlString.contains('<')) return htmlString.trim();
    try {
      // Szybkie usuwanie tagów bez pełnego parsera HTML tam gdzie to możliwe
      String cleaned = htmlString.replaceAll(RegExp(r'<(source|picture|script|style|zrodlo|figure|figcaption)[^>]*>.*?</\1>', caseSensitive: false), '');
      cleaned = cleaned.replaceAll(RegExp(r'<[^>]*>'), ' ');
      return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
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

    // RESTORE: Szukanie wewnątrz treści HTML (ważne dla Onet, RMF itp.)
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
        final href = link.href;
        if (href != null && _isValidImageUrl(href)) return href;
      }
    } catch (_) {}

    // RESTORE: Szukanie wewnątrz treści Atom (częste w blogach technologicznych)
    final htmlContent = item.content ?? item.summary ?? '';
    if (htmlContent.contains('<img')) {
      try {
        final doc = parse(htmlContent);
        final src = doc.querySelector('img')?.attributes['src'];
        if (src != null && _isValidImageUrl(src)) return src;
      } catch (_) {}
    }
    return null;
  }

  bool _isValidImageUrl(String url) {
    final u = url.toLowerCase();
    return u.contains('.jpg') || u.contains('.jpeg') || u.contains('.png') || 
           u.contains('.webp') || u.contains('.gif') || u.contains('image');
  }

  DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    if (dateValue is DateTime) return dateValue;
    if (dateValue is String) {
      if (dateValue.isEmpty) return DateTime.now();
      final cleaned = dateValue.trim();
      final parsed = DateTime.tryParse(cleaned);
      if (parsed != null) return parsed;
      try {
        final format = DateFormat("EEE, dd MMM yyyy HH:mm:ss Z", 'en_US');
        return format.parse(cleaned);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }
}
