import 'package:http/http.dart' as http;
import 'package:dart_rss/dart_rss.dart';
import 'package:html/parser.dart';
import 'package:intl/intl.dart';
import '../models/article.dart';
import '../models/news_source.dart';

class RssService {
  /// Pobiera artykuły z podanego źródła RSS
  Future<List<Article>> fetchArticles(NewsSource source) async {
    try {
      final response = await http.get(Uri.parse(source.rssUrl));

      if (response.statusCode == 200) {
        final feed = RssFeed.parse(response.body);
        
        return feed.items.map((item) {
          // Oczyszczamy opis z tagów HTML
          final cleanDescription = _parseHtmlString(item.description ?? '');
          
          return Article(
            id: item.guid ?? item.link ?? DateTime.now().toString(),
            title: item.title ?? 'Brak tytułu',
            description: cleanDescription,
            content: item.content?.value ?? cleanDescription,
            url: item.link ?? '',
            publishedAt: _parseRssDate(item.pubDate),
            sourceName: source.name,
            imageUrl: _extractImageUrl(item),
          );
        }).toList();
      } else {
        throw Exception('Błąd podczas pobierania RSS: ${response.statusCode}');
      }
    } catch (e) {
      print('RssService Error: $e');
      return [];
    }
  }

  /// Wyciąga URL obrazka z elementu RSS
  String? _extractImageUrl(RssItem item) {
    // 1. Sprawdzamy enclosure
    if (item.enclosure?.url != null) return item.enclosure!.url;
    
    // 2. Sprawdzamy media:content (częste w RSS 2.0)
    // dart_rss nie zawsze parsuje media:content automatycznie do oddzielnego pola, 
    // ale możemy spróbować wyciągnąć go z rozszerzeń, jeśli są dostępne.

    // 3. Sprawdzamy description pod kątem tagów <img>
    if (item.description != null && item.description!.contains('<img')) {
      try {
        final document = parse(item.description);
        final img = document.querySelector('img');
        return img?.attributes['src'];
      } catch (_) {}
    }
    return null;
  }

  /// Pomocnicza funkcja do usuwania HTML
  String _parseHtmlString(String htmlString) {
    final document = parse(htmlString);
    final String parsedString = parse(document.body?.text).documentElement?.text ?? '';
    return parsedString.trim();
  }

  /// Parsowanie daty z formatu RSS (RFC 822)
  DateTime _parseRssDate(String? dateString) {
    if (dateString == null) return DateTime.now();
    try {
      // Próba parsowania standardowego formatu RSS: "Tue, 21 Jul 2026 17:00:00 +0200"
      // Używamy DateFormat z biblioteki intl
      final format = DateFormat("EEE, dd MMM yyyy HH:mm:ss Z", 'en_US');
      return format.parse(dateString);
    } catch (_) {
      try {
        // Druga próba (bez strefy czasowej lub w innym formacie)
        return DateTime.parse(dateString);
      } catch (_) {
        return DateTime.now();
      }
    }
  }
}
