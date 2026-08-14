import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:prasowka/services/http_client.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/services/remote_config_service.dart';

class NewsApiService {
  static const _baseUrl = 'https://newsapi.org/v2';

  /// Domyślne źródła (jeśli Remote Config nie daje własnej listy).
  static const _defaultDomains = 'gazeta.pl,wiadomosci.onet.pl,tvn24.pl,radiozetka.pl,wyborcza.pl,interia.pl,wp.pl,wiadomosci.wp.pl';

  String? get _apiKey => RemoteConfigService().newsApiKey;
  String get _domains {
    final config = RemoteConfigService().newsApiDomains;
    return config.isNotEmpty ? config : _defaultDomains;
  }

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  Future<List<Article>> fetchArticles({int pageSize = 30}) async {
    if (!isConfigured) return [];
    try {
      final yesterday = DateTime.now().subtract(const Duration(days: 2));
      final from = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      final uri = Uri.parse('$_baseUrl/everything?domains=$_domains&language=pl&from=$from&sortBy=publishedAt&pageSize=$pageSize&apiKey=$_apiKey');
      final response = await HttpClient.instance.get(
        uri,
        timeout: const Duration(seconds: 20),
        maxRetries: 3,
      );
      if (response?.statusCode != 200) {
        debugPrint('NewsAPI Error: ${response?.statusCode}');
        return [];
      }
      final data = json.decode(response!.body);
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

int _simpleHash(String s) {
  int hash = 0;
  for (int i = 0; i < s.length; i++) {
    hash = ((hash << 5) - hash + s.codeUnitAt(i)) & 0x7FFFFFFF;
  }
  return hash;
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
        id: 'newsapi_${_simpleHash(url)}',
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
