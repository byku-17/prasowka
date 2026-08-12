import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/providers/tag_provider.dart';
import 'package:prasowka/widgets/article_card.dart';
import 'package:prasowka/widgets/empty_state_widget.dart';
import 'package:prasowka/widgets/section_header.dart';

Article _article({bool isRead = false}) => Article(
      id: 'art_1',
      title: 'Testowy tytul',
      description: 'Testowy opis artykulu',
      content: 'Tresc',
      url: 'https://example.com/art1',
      publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
      sourceName: 'TestPortal',
      isRead: isRead,
    );

Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ChangeNotifierProvider(create: (_) => NewsProvider()),
      ChangeNotifierProvider(create: (_) => TagProvider()),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('ArticleCard', () {
    testWidgets('pokazuje tytul, opis i zrodlo', (tester) async {
      await tester.pumpWidget(_wrap(ArticleCard(article: _article(), onTap: () {})));
      expect(find.text('Testowy tytul'), findsOneWidget);
      expect(find.text('Testowy opis artykulu'), findsOneWidget);
      expect(find.text('TESTPORTAL'), findsOneWidget);
    });

    testWidgets('pokazuje ikone przeczytanego artykulu', (tester) async {
      await tester.pumpWidget(_wrap(ArticleCard(article: _article(isRead: true), onTap: () {})));
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('onTap jest wywolywany po kliknieciu', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(ArticleCard(article: _article(), onTap: () => tapped = true)));
      await tester.tap(find.text('Testowy tytul'));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });

  group('EmptyStateWidget', () {
    testWidgets('pokazuje tytul i wiadomosc', (tester) async {
      await tester.pumpWidget(_wrap(const EmptyStateWidget(message: 'Brak internetu')));
      expect(find.text('BRAK TREŚCI'), findsOneWidget);
      expect(find.text('Brak internetu'), findsOneWidget);
    });

    testWidgets('przycisk retry wywoluje callback', (tester) async {
      var retried = false;
      await tester.pumpWidget(_wrap(EmptyStateWidget(message: 'x', onRetry: () => retried = true)));
      expect(find.text('POBIERZ PONOWNIE'), findsOneWidget);
      await tester.tap(find.text('POBIERZ PONOWNIE'));
      await tester.pump();
      expect(retried, isTrue);
    });
  });

  group('SectionHeader', () {
    testWidgets('pokazuje tytul sekcji', (tester) async {
      await tester.pumpWidget(_wrap(const SectionHeader('SPORT')));
      expect(find.text('SPORT'), findsOneWidget);
    });
  });
}
