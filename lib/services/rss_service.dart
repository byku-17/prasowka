import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dart_rss/dart_rss.dart';
import 'package:html/parser.dart';
import 'package:intl/intl.dart';
import '../models/article.dart';
import '../models/news_source.dart';

class RssService {
  /// Pobiera artykuły z podanego źródła RSS z timeoutem 10s
  Future<List<Article>> fetchArticles(NewsSource source) async {
    try {
      final response = await http
          .get(Uri.parse(source.rssUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final feed = RssFeed.parse(response.body);

        return feed.items.map((item) {
          // Oczyszczamy opis z tagów HTML
          final cleanDescription = _parseHtmlString(item.description ?? '');

          return Article(
            id: item.guid ?? item.link ?? DateTime.now().toIso8601String(),
            title: (item.title ?? 'Bez tytułu').trim(),
            description: cleanDescription,
            content: item.content?.value ?? cleanDescription,
            url: item.link ?? '',
            publishedAt: _parseRssDate(item.pubDate),
            sourceName: source.name,
            imageUrl: _extractImageUrl(item),
          );
        }).toList();
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('RssService Error for ${source.name}: $e');
      return [];
    }
  }

  /// Rozbudowane wyciąganie URL obrazka z elementu RSS
  String? _extractImageUrl(RssItem item) {
    // 1. Enclosure (standard RSS)
    if (item.enclosure?.url != null && _isImageUrl(item.enclosure!.url!)) {
      return item.enclosure!.url;
    }

    // 2. Description pod kątem tagów <img>
    if (item.description != null && item.description!.contains('<img')) {
      try {
        final document = parse(item.description);
        final img = document.querySelector('img');
        final src = img?.attributes['src'];
        if (src != null && _isImageUrl(src)) return src;
      } catch (_) {}
    }
    return null;
  }

  bool _isImageUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('.jpg') ||
        lowerUrl.contains('.jpeg') ||
        lowerUrl.contains('.png') ||
        lowerUrl.contains('.webp');
  }

  /// Pomocnicza funkcja do usuwania HTML
  String _parseHtmlString(String htmlString) {
    if (htmlString.isEmpty) return '';
    try {
      final document = parse(htmlString);
      final String parsedString =
          parse(document.body?.text).documentElement?.text ?? '';
      return parsedString.trim();
    } catch (_) {
      return htmlString;
    }
  }

  /// Parsowanie daty z formatu RSS (RFC 822) z wieloma fallbackami
  DateTime _parseRssDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return DateTime.now();
    
    final cleanedDate = dateString.trim();
    
    try {
      // Standard RSS: EEE, dd MMM yyyy HH:mm:ss Z
      final format = DateFormat("EEE, dd MMM yyyy HH:mm:ss Z", 'en_US');
      return format.parse(cleanedDate);
    } catch (_) {
      try {
        // Fallback: EEE, dd MMM yyyy HH:mm:ss zzz
        final format2 = DateFormat("EEE, dd MMM yyyy HH:mm:ss zzz", 'en_US');
        return format2.parse(cleanedDate);
      } catch (_) {
        try {
          return DateTime.parse(cleanedDate);
        } catch (_) {
          debugPrint('Could not parse RSS date: $cleanedDate');
          return DateTime.now();
        }
      }
    }
  }
}
