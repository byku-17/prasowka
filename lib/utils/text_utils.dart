class TextUtils {
  static const _polish = 'ąćęłńóśźż';
  static const _latin = 'acelnoszz';

  /// Zamienia polskie znaki na łacińskie (lowercase).
  static String stripPolish(String text) {
    var str = text.toLowerCase();
    for (int i = 0; i < _polish.length; i++) {
      str = str.replaceAll(_polish[i], _latin[i]);
    }
    return str;
  }

  /// Normalizuje tekst do porównywania (polskie znaki → łacińskie, usuwa dodatki klubowe)
  static String normalize(String text) {
    var str = stripPolish(text);
    str = str.replaceAll('fc ', '').replaceAll(' ks ', '').replaceAll(' gks ', '').replaceAll(' pko bp ', '');
    return str.trim();
  }

  /// Sprawdza czy szukana fraza pasuje do tekstu z API.
  /// Obsługuje: contains (min 4 znaki), startsWith (min 4 znaki), oraz dopasowanie prefixowe słów
  /// (np. "osipovici" pasuje do "osipovichi" bo 8/9 znaków wspólnych na początku)
  static bool fuzzyMatch(String searchable, String query) {
    if (query.length >= 4 && searchable.contains(query)) return true;

    final words = searchable.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.length < 4 || query.length < 4) continue;
      if (word.startsWith(query) || query.startsWith(word)) return true;
      final minLen = word.length < query.length ? word.length : query.length;
      if (minLen >= 6) {
        int match = 0;
        for (int i = 0; i < minLen; i++) {
          if (word[i] == query[i]) {
            match++;
          } else {
            break;
          }
          if (match >= 6) return true;
        }
      }
    }
    return false;
  }
}
