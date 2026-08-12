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
}
