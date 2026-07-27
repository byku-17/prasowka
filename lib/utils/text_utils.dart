class TextUtils {
  /// Normalizuje tekst do porównywania (polskie znaki → łacińskie, usuwa dodatki klubowe)
  static String normalize(String text) {
    var str = text.toLowerCase();
    const polish = 'ąćęłńóśźż';
    const latin = 'acelnoszz';
    for (int i = 0; i < polish.length; i++) {
      str = str.replaceAll(polish[i], latin[i]);
    }
    str = str.replaceAll('fc ', '').replaceAll(' ks ', '').replaceAll(' gks ', '').replaceAll(' pko bp ', '');
    return str.trim();
  }
}
