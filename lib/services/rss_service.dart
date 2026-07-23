import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dart_rss/dart_rss.dart';
import 'package:html/parser.dart';
import 'package:intl/intl.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/models/news_source.dart';

class RssService {
  /// Pobiera i parsuje artykuły w sposób wielowątkowy
  Future<List<Article>> fetchArticles(NewsSource source) async {
    final url = source.rssUrl.trim();
    debugPrint('Sowa Network: PRÓBA -> ${source.name} ($url)');
    
    try {
      final uri = Uri.parse(url);
      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Accept': 'application/rss+xml, application/xml, text/xml, */*',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        // Przenosimy ciężkie dekodowanie i parsowanie do osobnego wątku (Isolate)
        final List<Article> articles = await compute(_parseAndCleanCompute, {
          'bodyBytes': response.bodyBytes,
          'sourceName': source.name,
        });
        
        debugPrint('Sowa Network: SUKCES -> ${source.name} (${articles.length} news)');
        return articles;
      } else {
        debugPrint('Sowa Network: BŁĄD HTTP ${response.statusCode} -> ${source.name}');
        return [];
      }
    } catch (e) {
      debugPrint('Sowa Network: KATASTROFA -> ${source.name}: $e');
      return []; 
    }
  }
}

/// Funkcja działająca w osobnym wątku (Isolate)
List<Article> _parseAndCleanCompute(Map<String, dynamic> data) {
  final Uint8List bodyBytes = data['bodyBytes'];
  final String sourceName = data['sourceName'];

  String xml;
  try {
    xml = utf8.decode(bodyBytes, allowMalformed: true);
  } catch (_) {
    xml = latin1.decode(bodyBytes);
  }
  
  final trimmedXml = xml.trim();
  final List<Article> articles = [];

  try {
    try {
      final feed = RssFeed.parse(trimmedXml);
      for (var item in feed.items) {
        articles.add(Article(
          id: item.guid ?? item.link ?? DateTime.now().toIso8601String(),
          title: (item.title ?? 'Bez tytułu').trim(),
          description: _cleanHtmlInternal(item.description ?? ''),
          content: item.content?.value ?? item.description ?? '',
          url: item.link ?? '',
          publishedAt: _parseDateInternal(item.pubDate),
          sourceName: sourceName,
          imageUrl: _getImgInternal(item),
        ));
      }
      return articles;
    } catch (_) {
      final feed = AtomFeed.parse(trimmedXml);
      for (var item in feed.items) {
        articles.add(Article(
          id: item.id ?? (item.links.isNotEmpty ? item.links.first.href : null) ?? DateTime.now().toIso8601String(),
          title: (item.title ?? 'Bez tytułu').trim(),
          description: _cleanHtmlInternal(item.summary ?? ''),
          content: item.content ?? item.summary ?? '',
          url: item.links.isNotEmpty ? item.links.first.href ?? '' : '',
          publishedAt: _parseDateInternal(item.updated ?? item.published),
          sourceName: sourceName,
          imageUrl: _getAtomImgInternal(item),
        ));
      }
      return articles;
    }
  } catch (e) {
    return [];
  }
}

String _cleanHtmlInternal(String htmlString) {
  if (htmlString.isEmpty) return '';
  if (!htmlString.contains('<')) return htmlString.trim();
  
  try {
    String cleaned = htmlString.replaceAll(RegExp(r'<(source|picture|script|style|zrodlo|figure|figcaption)[^>]*>', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'<\/(source|picture|script|style|zrodlo|figure|figcaption)>', caseSensitive: false), '');
    final document = parse(cleaned);
    return (document.body?.text ?? '').trim();
  } catch (_) {
    return htmlString.trim();
  }
}

String? _getImgInternal(RssItem item) {
  try {
    if (item.media?.contents != null && item.media!.contents.isNotEmpty) {
      final url = item.media!.contents.first.url;
      if (url != null && _isValidImageUrlInternal(url)) return url;
    }
    if (item.media?.thumbnails != null && item.media!.thumbnails.isNotEmpty) {
      final url = item.media!.thumbnails.first.url;
      if (url != null && _isValidImageUrlInternal(url)) return url;
    }
  } catch (_) {}
  
  if (item.enclosure?.url != null && _isValidImageUrlInternal(item.enclosure!.url!)) return item.enclosure!.url;
  if (item.itunes?.image?.href != null && _isValidImageUrlInternal(item.itunes!.image!.href!)) return item.itunes!.image!.href;
  
  if (item.content?.value != null && item.content!.value!.contains('<img')) {
    try {
      final doc = parse(item.content!.value);
      final src = doc.querySelector('img')?.attributes['src'];
      if (src != null && _isValidImageUrlInternal(src)) return src;
    } catch (_) {}
  }
  
  if (item.description != null && item.description!.contains('<img')) {
    try {
      final doc = parse(item.description);
      final src = doc.querySelector('img')?.attributes['src'];
      if (src != null && _isValidImageUrlInternal(src)) return src;
    } catch (_) {}
  }
  return null;
}

String? _getAtomImgInternal(AtomItem item) {
  try {
    for (var link in item.links) {
      final href = link.href;
      if ((link.rel == 'enclosure' || link.rel == 'image') && href != null && _isValidImageUrlInternal(href)) {
        return href;
      }
      if (href != null && _isValidImageUrlInternal(href)) {
        return href;
      }
    }
  } catch (_) {}
  final source = item.content ?? item.summary ?? '';
  if (source.contains('<img')) {
    try {
      final document = parse(source);
      final src = document.querySelector('img')?.attributes['src'];
      if (src != null && _isValidImageUrlInternal(src)) return src;
    } catch (_) {}
  }
  return null;
}

bool _isValidImageUrlInternal(String url) {
  final u = url.toLowerCase();
  return u.contains('.jpg') || u.contains('.jpeg') || u.contains('.png') || 
         u.contains('.webp') || u.contains('.gif') || u.contains('image');
}

DateTime _parseDateInternal(dynamic dateValue) {
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
      try {
        final format2 = DateFormat("EEE, dd MMM yyyy HH:mm:ss zzz", 'en_US');
        return format2.parse(cleaned);
      } catch (_) {
         return DateTime.now();
      }
    }
  }
  return DateTime.now();
}
