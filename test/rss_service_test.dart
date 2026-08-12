import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasowka/models/news_source.dart';
import 'package:prasowka/services/rss_service.dart';

const _rssXml = '''<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Test Kanal</title>
    <link>https://example.com</link>
    <description>Testowy kanal</description>
    <item>
      <guid>item-1</guid>
      <title>Pierwszy artykul</title>
      <description><![CDATA[<p>Opis z <b>HTML</b> i <script>zly</script></p>]]></description>
      <link>https://example.com/art1</link>
      <pubDate>Mon, 11 Aug 2026 10:00:00 +0000</pubDate>
    </item>
    <item>
      <guid>item-2</guid>
      <title>Drugi artykul</title>
      <description>Zwykly opis bez HTML</description>
      <link>https://example.com/art2</link>
      <pubDate>Tue, 12 Aug 2026 08:30:00 +0000</pubDate>
    </item>
  </channel>
</rss>
''';

void main() {
  group('RssService.fetchArticles (lokalny HTTP)', () {
    test('parsuje RSS z serwera lokalnego i czyści HTML', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) {
        request.response.statusCode = 200;
        request.response.headers.contentType =
            ContentType('application', 'xml', charset: 'utf-8');
        request.response.write(_rssXml);
        request.response.close();
      });

      final source = NewsSource(
        id: 'test_feed',
        name: 'Test Zrodlo',
        rssUrl: 'http://127.0.0.1:${server.port}/feed',
        categoryId: 'tech',
      );

      final articles = await RssService().fetchArticles(source);
      expect(articles, hasLength(2));
      expect(articles[0].title, 'Pierwszy artykul');
      expect(articles[0].url, 'https://example.com/art1');
      expect(articles[0].sourceName, 'Test Zrodlo');
      expect(articles[0].description, contains('Opis z'));
      expect(articles[0].description, isNot(contains('<')));
      expect(articles[0].description, isNot(contains('zly')));
      expect(articles[1].title, 'Drugi artykul');
      expect(articles[0].id, 'test_feed_item-1');
      expect(articles[1].id, 'test_feed_item-2');
    });

    test('ten sam guid z dwoch zrodel nie koliduje', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) {
        request.response.statusCode = 200;
        request.response.headers.contentType =
            ContentType('application', 'xml', charset: 'utf-8');
        request.response.write(_rssXml);
        request.response.close();
      });

      final sourceA = NewsSource(
        id: 'feed_a',
        name: 'Feed A',
        rssUrl: 'http://127.0.0.1:${server.port}/feed',
        categoryId: 'tech',
      );
      final sourceB = NewsSource(
        id: 'feed_b',
        name: 'Feed B',
        rssUrl: 'http://127.0.0.1:${server.port}/feed',
        categoryId: 'tech',
      );

      final articlesA = await RssService().fetchArticles(sourceA);
      final articlesB = await RssService().fetchArticles(sourceB);

      expect(articlesA[0].id, 'feed_a_item-1');
      expect(articlesB[0].id, 'feed_b_item-1');
      expect(articlesA[0].id, isNot(articlesB[0].id));
    });
  });

  group('extractRealUrlFromContent (Google News)', () {
    test('wyciaga prawdziwy URL z content', () {
      final url = RssService.extractRealUrlFromContent(
        '<a href="https://tvn24.pl/prawdziwy-artykul">https://news.google.com/redirect</a>',
      );
      expect(url, 'https://tvn24.pl/prawdziwy-artykul');
    });

    test('pomija linki do news.google.com', () {
      final url = RssService.extractRealUrlFromContent(
        '<a href="https://news.google.com/rss/articles/abc">link</a>',
      );
      expect(url, isNull);
    });

    test('zwraca null dla pustego content', () {
      expect(RssService.extractRealUrlFromContent(null), isNull);
      expect(RssService.extractRealUrlFromContent(''), isNull);
    });
  });

  group('isGoogleNewsUrl', () {
    test('rozpoznaje URL Google News', () {
      expect(RssService.isGoogleNewsUrl('https://news.google.com/rss/articles/abc'), isTrue);
      expect(RssService.isGoogleNewsUrl('https://tvn24.pl/artykul'), isFalse);
      expect(RssService.isGoogleNewsUrl(null), isFalse);
    });
  });
}
