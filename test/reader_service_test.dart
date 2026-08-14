import 'package:flutter_test/flutter_test.dart';
import 'package:prasowka/services/reader_service.dart';

void main() {
  group('ReaderService.normalizeHtml', () {
    test('zwija serie 2+ br w jeden', () {
      expect(
        ReaderService.normalizeHtml('A<br>B<br><br>C<br><br><br>D'),
        'A<br>B<br>C<br>D',
      );
    });

    test('usuwa puste paragrafy (w tym z samymi br)', () {
      expect(
        ReaderService.normalizeHtml(
          '<p>tekst</p><p></p><p><br></p><p><br><br></p><p>koniec</p>',
        ),
        '<p>tekst</p><p>koniec</p>',
      );
    });

    test('usuwa biale znaki przed nowa linia', () {
      expect(ReaderService.normalizeHtml('a  \nb\n\n\nc'), 'a\nb\n\nc');
    });

    test('zwija 3+ nowe linie do dwoch', () {
      expect(ReaderService.normalizeHtml('a\n\n\n\n\nb'), 'a\n\nb');
    });

    test('pusty string zostaje pusty', () {
      expect(ReaderService.normalizeHtml(''), '');
    });
  });

  group('ReaderService.isLeadDuplicated', () {
    test('opis = poczatek tresci -> true', () {
      expect(
        ReaderService.isLeadDuplicated(
          'Pierwszy akapit o czyms bardzo waznym.',
          '<p>Pierwszy akapit o czyms bardzo waznym. Drugi akapit.</p>',
        ),
        isTrue,
      );
    });

    test('opis inny niz tresc -> false', () {
      expect(
        ReaderService.isLeadDuplicated(
          'Zupelnie inny opis.',
          '<p>Cos calkowicie odmiennego.</p>',
        ),
        isFalse,
      );
    });

    test('null opis -> false', () {
      expect(ReaderService.isLeadDuplicated(null, '<p>tresc</p>'), isFalse);
    });

    test('encje HTML (nbsp) w tresci nie psuja wykrycia -> true', () {
      expect(
        ReaderService.isLeadDuplicated(
          'Pierwszy akapit o czyms.',
          '<p>Pierwszy akapit&nbsp;o czyms. Drugi akapit.</p>',
        ),
        isTrue,
      );
    });

    test('opis z tagami HTML -> true', () {
      expect(
        ReaderService.isLeadDuplicated(
          '<strong>Pierwszy</strong> akapit o czyms.',
          '<p><strong>Pierwszy</strong> akapit o czyms. Dalej idzie tekst.</p>',
        ),
        isTrue,
      );
    });

    test('opis przyciety wielokropkiem -> true', () {
      expect(
        ReaderService.isLeadDuplicated(
          'Pierwszy akapit o czyms bardzo waznym…',
          '<p>Pierwszy akapit o czyms bardzo waznym i jeszcze dalszy ciag.</p>',
        ),
        isTrue,
      );
    });

    test('lead dalej niz oczekiwano (prog 70% slow) -> true', () {
      expect(
        ReaderService.isLeadDuplicated(
          'Dlugiszy opis rozpoczynajacy artykul o bardzo waznym temacie polityki',
          '<p>Dlugiszy opis rozpoczynajacy artykul o bardzo waznym temacie i cala reszta zdania dalej.</p>',
        ),
        isTrue,
      );
    });

    test('poczatek tresci bez tekstu (figure) nie udaje opisu -> false', () {
      expect(
        ReaderService.isLeadDuplicated(
          'Zupelnie inny opis.',
          '<figure><img src="x.jpg"/></figure><p>Cos calkowicie odmiennego.</p>',
        ),
        isFalse,
      );
    });
  });

  group('ReaderService.stripInlineFootnoteMarkers', () {
    test('usuwa znaczniki [n]', () {
      expect(
        ReaderService.stripInlineFootnoteMarkers('Tekst [1] dalej [2].'),
        'Tekst dalej.',
      );
    });

    test('usuwa samotne znaczniki † i #', () {
      expect(
        ReaderService.stripInlineFootnoteMarkers('Wyniki † zostały potwierdzone.'),
        'Wyniki zostały potwierdzone.',
      );
    });

    test('zostawia zwykly tekst bez zmian', () {
      expect(
        ReaderService.stripInlineFootnoteMarkers('Zwykly, normalny tekst.'),
        'Zwykly, normalny tekst.',
      );
    });
  });

  group('ReaderService.stripJunkBlocks', () {
    test('usuwa blok Zobacz takze', () {
      final out = ReaderService.stripJunkBlocks(
        '<p>Wazny akapit tresci.</p><p>Zobacz także: kolejna wiadomosc</p>',
      );
      expect(out.contains('Wazny akapit tresci.'), isTrue);
      expect(out.contains('Zobacz także'), isFalse);
    });

    test('usuwa linie Zrodlo i byline', () {
      final out = ReaderService.stripJunkBlocks(
        '<p>Tekst artykulu.</p><p>Źródło: przykład.pl</p><p>Autor: Jan Kowalski</p>',
      );
      expect(out.contains('Tekst artykulu.'), isTrue);
      expect(out.contains('Źródło:'), isFalse);
      expect(out.contains('Autor:'), isFalse);
    });

    test('usuwa blok z samym linkiem', () {
      final out = ReaderService.stripJunkBlocks(
        '<p><a href="https://example.com/1">Podobny artykul 1</a></p>',
      );
      expect(out.contains('Podobny artykul'), isFalse);
    });

    test('zostawia dlugi wazny akapit', () {
      final longText = 'Zobacz już teraz, jak to wszystko działa w praktyce. ' * 10;
      final out = ReaderService.stripJunkBlocks('<p>$longText</p>');
      expect(out.contains('działa w praktyce'), isTrue);
    });
  });
}
