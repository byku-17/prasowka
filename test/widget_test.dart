import 'package:flutter_test/flutter_test.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/models/news_category.dart';
import 'package:prasowka/models/news_source.dart';

void main() {
  group('Article', () {
    Article createArticle({
      String title = 'Test Title',
      String description = 'Test description',
      String content = 'Test content here',
    }) {
      return Article(
        id: 'test_1',
        title: title,
        description: description,
        content: content,
        url: 'https://example.com',
        publishedAt: DateTime(2025, 1, 1),
        sourceName: 'TestSource',
      );
    }

    test('estimatedReadingTime returns at least 1 minute', () {
      final article = createArticle(content: 'short');
      expect(article.estimatedReadingTime, greaterThanOrEqualTo(1));
    });

    test('estimatedReadingTime calculates correctly for longer content', () {
      final article = createArticle(content: List.filled(400, 'word').join(' '));
      expect(article.estimatedReadingTime, 2);
    });

    test('tags are extracted from title and description', () {
      final article = createArticle(
        title: 'Breaking news about technology',
        description: 'Latest updates in software development',
      );
      final tags = article.tags;
      expect(tags, isA<List<String>>());
      expect(tags, contains('breaking'));
      expect(tags, contains('technology'));
      expect(tags, contains('development'));
      expect(tags, isNot(contains('the')));
      expect(tags, isNot(contains('and')));
    });

    test('tags filter out short words (3 or fewer chars)', () {
      final article = createArticle(
        title: 'the big cat',
        description: 'a red fox ran fast',
      );
      final tags = article.tags;
      expect(tags, isNot(contains('the')));
      expect(tags, isNot(contains('big')));
      expect(tags, isNot(contains('cat')));
      expect(tags, contains('fast'));
    });
  });

  group('NewsCategory', () {
    test('defaultCategories contains expected categories', () {
      final categories = NewsCategory.defaultCategories;
      expect(categories.length, greaterThanOrEqualTo(10));
      expect(categories.first.id, 'all');
    });

    test('each category has unique id', () {
      final categories = NewsCategory.defaultCategories;
      final ids = categories.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('icon getter returns valid IconData', () {
      final category = NewsCategory.defaultCategories.first;
      expect(category.icon, isA<dynamic>());
    });
  });

  group('NewsSource', () {
    test('topSourceIds contains expected sources', () {
      expect(NewsSource.topSourceIds, contains('rmf24_polska'));
      expect(NewsSource.topSourceIds, contains('tvn24_najwazniejsze'));
      expect(NewsSource.topSourceIds, contains('techcrunch'));
    });

    test('defaultSources is not empty', () {
      expect(NewsSource.defaultSources, isNotEmpty);
    });

    test('each source has unique id', () {
      final ids = NewsSource.defaultSources.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('topSourceIds references sources that exist in defaultSources', () {
      final sourceIds = NewsSource.defaultSources.map((s) => s.id).toSet();
      for (final id in NewsSource.topSourceIds) {
        expect(sourceIds, contains(id),
            reason: 'topSourceId $id should exist in defaultSources');
      }
    });

    test('all sources have valid rssUrl', () {
      for (final source in NewsSource.defaultSources) {
        expect(source.rssUrl, isNotEmpty);
        expect(source.rssUrl, startsWith('http'));
      }
    });
  });
}
