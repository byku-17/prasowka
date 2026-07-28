import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:prasowka/models/article.dart';

class NewsApiService {
  static const _baseUrl = 'https://newsapi.org/v2';

  String? get _apiKey => dotenv.env['NEWSAPI_KEY'];

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  Future<List<Article>> fetchTopHeadlines({String country = 'pl', int pageSize = 30}) async {
    if (!isConfigured) return [];
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 2));
      final from = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      final uri = Uri.parse('$_baseUrl/everything?domains=gazeta.pl,wiadomosci.onet.pl,tvn24.pl,radiozetka.pl,wyborcza.pl,interia.pl,wp.pl,wiadomosci.wp.pl&language=pl&from=$from&sortBy=publishedAt&pageSize=$pageSize&apiKey=$_apiKey');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        debugPrint('NewsAPI Error: ${response.statusCode}');
        return [];
      }
      final data = json.decode(response.body);
      if (data['status'] != 'ok') {
        debugPrint('NewsAPI Error: ${data['message']}');
        return [];
      }
      return await compute(_parseArticles, response.body);
    } catch (e) {
      debugPrint('NewsAPI Exception: $e');
      return [];
    }
  }
}

List<Article> _parseArticles(String jsonBody) {
  final data = json.decode(jsonBody);
  final articles = <Article>[];
  for (final item in data['articles'] ?? []) {
    final title = (item['title'] ?? 'Bez tytułu').trim();
    if (title == '[Removed]') continue;
    final description = (item['description'] ?? '').trim();
    final url = item['url'] ?? '';
    if (url.isEmpty) continue;
    final sourceName = item['source']?['name'] ?? 'Unknown';
    final imageUrl = item['urlToImage'];
    final publishedAt = item['publishedAt'] != null
        ? DateTime.tryParse(item['publishedAt']) ?? DateTime.now()
        : DateTime.now();

    articles.add(Article(
      id: 'newsapi_${url.hashCode}',
      title: title,
      description: description.isNotEmpty ? description : 'Artykuł ze źródła: $sourceName',
      content: item['content'] ?? '',
      url: url,
      publishedAt: publishedAt,
      sourceName: sourceName,
      imageUrl: imageUrl,
    ));
  }
  return articles;
}
