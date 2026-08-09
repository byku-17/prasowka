import 'package:flutter_test/flutter_test.dart';
import 'package:prasowka/screens/article_detail_screen.dart';

void main() {
  test('dzieli na zdania po kropce z wielka litera', () {
    final chunks = ArticleDetailScreen.debugSpeechChunks('Ala ma kota. Basia ma psa. Ale to koniec.');
    expect(chunks, ['Ala ma kota.', 'Basia ma psa.', 'Ale to koniec.']);
  });

  test('nie dzieli po skrotach np. i m.in.', () {
    final chunks = ArticleDetailScreen.debugSpeechChunks('Mamy np. jabłka. Zobacz m.in. to. Koniec.');
    expect(chunks, ['Mamy np. jabłka.', 'Zobacz m.in. to.', 'Koniec.']);
  });

  test('dzieli po nowej linii i ?', () {
    final chunks = ArticleDetailScreen.debugSpeechChunks('Czy to działa?\nTak działa.\n\n\nNastępny.');
    expect(chunks, ['Czy to działa?', 'Tak działa.', 'Następny.']);
  });

  test('dlugie zdanie jest pociete', () {
    final long = 'X' * 700 + '.';
    final chunks = ArticleDetailScreen.debugSpeechChunks(long);
    expect(chunks.length, greaterThan(1));
  });
}
