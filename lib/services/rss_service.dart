import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dart_rss/dart_rss.dart';
import 'package:html/parser.dart';
import 'package:intl/intl.dart';
import '../models/article.dart';
import '../models/news_source.dart';

class RssService {
  /// Pobiera artykuły z podanego źródła RSS z timeoutem 10s
  /// Używa Isolates (compute) do ciężkiego parsowania XML w tle
  Future<List<Article>> fetchArticles(NewsSource source) async {
    try {
      final response = await http
          .get(Uri.parse(source.rssUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Przenosimy parsowanie do osobnego wątku (Isolate)
        return await compute(_parseRssCompute, {
          'xml': response.body,
          'sourceName': source.name,
        });
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('RssService Error for ${source.name}: $e');
      return [];
    }
  }
}

/// Funkcja pomocnicza działająca w osobnym wątku (Isolate)
List<Article> _parseRssCompute(Map<String, dynamic> data) {
  final String xml = data['xml'];
  final String sourceName = data['sourceName'];
  
  try {
    final feed = RssFeed.parse(xml);
    return feed.items.map((item) {
      final description = _cleanHtml(item.description ?? '');
      return Article(
        id: item.guid ?? item.link ?? DateTime.now().toIso8601String(),
        title: (item.title ?? 'Bez tytułu').trim(),
        description: description,
        content: item.content?.value ?? description,
        url: item.link ?? '',
        publishedAt: _parseDate(item.pubDate),
        sourceName: sourceName,
        imageUrl: _getImg(item),
      );
    }).toList();
  } catch (e) {
    return [];
  }
}

String _cleanHtml(String htmlString) {
  if (htmlString.isEmpty) return '';
  final document = parse(htmlString);
  return parse(document.body?.text).documentElement?.text?.trim() ?? '';
}

String? _getImg(RssItem item) {
  if (item.enclosure?.url != null) return item.enclosure!.url;
  if (item.description != null && item.description!.contains('<img')) {
    try {
      final document = parse(item.description);
      return document.querySelector('img')?.attributes['src'];
    } catch (_) {}
  }
  return null;
}

DateTime _parseDate(String? dateString) {
  if (dateString == null || dateString.isEmpty) return DateTime.now();
  try {
    final format = DateFormat("EEE, dd MMM yyyy HH:mm:ss Z", 'en_US');
    return format.parse(dateString.trim());
  } catch (_) {
    try {
      return DateTime.parse(dateString.trim());
    } catch (_) {
      return DateTime.now();
    }
  }
}
