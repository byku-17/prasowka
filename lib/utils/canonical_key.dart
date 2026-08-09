import 'package:prasowka/models/sport_event.dart';

/// Canonical key for deduplicating matches across sources (SportDB, ESPN, TSDB).
///
/// Normalizuje team names + competition + date → ten sam mecz z różnych API
/// dostaje ten sam klucz, niezależnie od formatu ID źródła.
class CanonicalKey {
  CanonicalKey._();

  /// Generuje kanoniczny klucz meczu.
  ///
  /// Format: `{type}_{home}_{away}_{date}_{comp}`
  /// Przykład: `football_barcelona_real_madrid_20260806_la_liga`
  static String generate(MatchEvent event) {
    final type = event.type.name;
    final home = _normalizeTeam(event.homeTeam);
    final away = _normalizeTeam(event.awayTeam);
    final date = _normalizeDate(event.date);
    final comp = _normalizeCompetition(event.competition);
    return '${type}_${home}_${away}_${date}_$comp';
  }

  /// Normalizuje nazwę drużyny:
  /// - lowercase
  /// - polskie znaki → łacińskie
  /// - usuwa sufiksy klubowe (FC, SC, CF, AC, AS, SV, BK, IF, FK, CD, CF, etc.)
  /// - usuwa "the ", "afc ", "cf "
  /// - scala białe znaki
  static String _normalizeTeam(String name) {
    var s = name.toLowerCase().trim();

    // Polskie znaki → łacińskie
    const polish = 'ąćęłńóśźż';
    const latin = 'acelnoszz';
    for (int i = 0; i < polish.length; i++) {
      s = s.replaceAll(polish[i], latin[i]);
    }

    // Usuń prefiksy/sufiksy klubowe
    const suffixes = [
      ' fc', ' sc', ' cf', ' ac', ' as', ' sv', ' bk', ' if', ' fk',
      ' cd', ' ec', ' gc', ' rc', ' ud', ' sd', ' ss', ' sg', ' og',
      'afc ', 'cf ', 'sc ', 'ssc ', 'usd ', 'uc ', 'ac ', 'as ', 'rc ',
    ];
    for (final suffix in suffixes) {
      s = s.replaceAll(suffix, '');
    }

    // Usuń "the "
    if (s.startsWith('the ')) s = s.substring(4);

    // Usuń redundantne spacje
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// Normalizuje nazwę rozgrywek:
  /// - lowercase, usuwa polskie znaki
  /// - scala warianty ("la liga" / "laliga" / "laliga Santander")
  /// - usuwa sponsorów
  static String _normalizeCompetition(String name) {
    var s = name.toLowerCase().trim();

    const polish = 'ąćęłńóśźż';
    const latin = 'acelnoszz';
    for (int i = 0; i < polish.length; i++) {
      s = s.replaceAll(polish[i], latin[i]);
    }

    // Usuń sponsorów i副冠名
    s = s.replaceAll('santander', '').replaceAll('bank pekao sa', '')
        .replaceAll('bwin', '').replaceAll('euro', '').replaceAll('pepsico', '')
        .replaceAll(RegExp(r'\s+'), ' ').trim();

    // Znormalizuj znane ligi
    const aliases = {
      'laliga': 'la_liga',
      'la liga': 'la_liga',
      'premier league': 'premier_league',
      'ekstraklasa': 'ekstraklasa',
      'serie a': 'serie_a',
      'bundesliga': 'bundesliga',
      'ligue 1': 'ligue_1',
      'champions league': 'champions_league',
      'liga mistrzow': 'champions_league',
      'europa league': 'europa_league',
      'liga europy': 'europa_league',
      'eredivisie': 'eredivisie',
      'liga portugal': 'liga_portugal',
      'primeira liga': 'liga_portugal',
      'super lig': 'super_lig',
      'superliga': 'superliga',
      'nba': 'nba',
      'euroleague': 'euroleague',
      'euroliga': 'euroleague',
      'plk': 'plk',
      'nhl': 'nhl',
      'shl': 'shl',
      'liiga': 'liiga',
      'nfl': 'nfl',
      'mlb': 'mlb',
      'formula 1': 'f1',
      'formula1': 'f1',
      'f1': 'f1',
    };

    for (final entry in aliases.entries) {
      // Dopasowanie częściowe: "English Premier League" → "premier_league",
      // "La Liga Santander" → "la_liga". Najpierw pełne (bezpieczniejsze),
      // potem zawieranie (żeby warianty z prefiksem kraju się scalały).
      if (s == entry.key) return entry.value;
    }
    // Posortuj aliasy malejąco po długości klucza, żeby najpierw trafiały
    // nazwy bardziej specyficzne (np. "champions league" przed "league").
    final sorted = aliases.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final entry in sorted) {
      if (s.contains(entry.key)) return entry.value;
    }

    return s.replaceAll(RegExp(r'\s+'), '_');
  }

  /// Normalizuje datę do formatu YYYYMMDD (bezrefencyjnie).
  static String _normalizeDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Porównuje dwa MatchEvent pod kątem canonical key.
  static bool isSameMatch(MatchEvent a, MatchEvent b) {
    return generate(a) == generate(b);
  }
}
