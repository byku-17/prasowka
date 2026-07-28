import 'package:prasowka/models/sport_event.dart';

enum SportDiscipline {
  football('Piłka Nożna', '⚽'),
  basketball('Koszykówka', '🏀'),
  hockey('Hokej', '🏒'),
  volleyball('Siatkówka', '🏐'),
  handball('Piłka Ręczna', '🤾'),
  tennis('Tenis', '🎾'),
  f1('Formula 1', '🏎️'),
  wrc('WRC', '🏁'),
  nfl('Football Amerykański', '🏈'),
  mlb('Baseball', '⚾');

  final String displayName;
  final String emoji;
  const SportDiscipline(this.displayName, this.emoji);
}

class SportLeague {
  final String id;
  final String name;
  final String country;
  final String? countryCode;
  final SportDiscipline discipline;
  final SportType sportType;

  /// ESPN API: /site/api.espn.com/.../sports/{sport}/{league}/scoreboard
  final String? espnSport;
  final String? espnLeague;

  /// TheSportsDB league ID (for football)
  final String? tsdbLeagueId;

  /// Flashscore URL (fallback when no API data)
  final String? flashscoreUrl;

  /// Flashscore search URL template (league name as search query)
  final String? flashscoreSearchUrl;

  const SportLeague({
    required this.id,
    required this.name,
    required this.country,
    this.countryCode,
    required this.discipline,
    required this.sportType,
    this.espnSport,
    this.espnLeague,
    this.tsdbLeagueId,
    this.flashscoreUrl,
    this.flashscoreSearchUrl,
  });

  bool get hasApi => espnSport != null || tsdbLeagueId != null;

  /// All available leagues
  static const List<SportLeague> allLeagues = [
    // ─── PIŁKA NOŻNA ───
    SportLeague(
      id: 'football_premier_league',
      name: 'Premier League',
      country: 'Anglia',
      countryCode: 'GB',
      discipline: SportDiscipline.football,
      sportType: SportType.football,
      espnSport: 'soccer',
      espnLeague: 'eng.1',
      tsdbLeagueId: '4328',
      flashscoreUrl: 'https://www.flashscore.com/football/england/premier-league/',
    ),
    SportLeague(
      id: 'football_serie_a',
      name: 'Serie A',
      country: 'Włochy',
      countryCode: 'IT',
      discipline: SportDiscipline.football,
      sportType: SportType.football,
      espnSport: 'soccer',
      espnLeague: 'ita.1',
      tsdbLeagueId: '4335',
      flashscoreUrl: 'https://www.flashscore.com/football/italy/serie-a/',
    ),
    SportLeague(
      id: 'football_la_liga',
      name: 'La Liga',
      country: 'Hiszpania',
      countryCode: 'ES',
      discipline: SportDiscipline.football,
      sportType: SportType.football,
      espnSport: 'soccer',
      espnLeague: 'esp.1',
      tsdbLeagueId: '4334',
      flashscoreUrl: 'https://www.flashscore.com/football/spain/laliga/',
    ),
    SportLeague(
      id: 'football_bundesliga',
      name: 'Bundesliga',
      country: 'Niemcy',
      countryCode: 'DE',
      discipline: SportDiscipline.football,
      sportType: SportType.football,
      espnSport: 'soccer',
      espnLeague: 'ger.1',
      tsdbLeagueId: '4331',
      flashscoreUrl: 'https://www.flashscore.com/football/germany/bundesliga/',
    ),
    SportLeague(
      id: 'football_ligue_1',
      name: 'Ligue 1',
      country: 'Francja',
      countryCode: 'FR',
      discipline: SportDiscipline.football,
      sportType: SportType.football,
      espnSport: 'soccer',
      espnLeague: 'fra.1',
      tsdbLeagueId: '4332',
      flashscoreUrl: 'https://www.flashscore.com/football/france/ligue-1/',
    ),
    SportLeague(
      id: 'football_liga_portugal',
      name: 'Liga Portugal',
      country: 'Portugalia',
      countryCode: 'PT',
      discipline: SportDiscipline.football,
      sportType: SportType.football,
      espnSport: 'soccer',
      espnLeague: 'por.1',
      flashscoreUrl: 'https://www.flashscore.com/football/portugal/liga-portugal/',
    ),
    SportLeague(
      id: 'football_eredivisie',
      name: 'Eredivisie',
      country: 'Holandia',
      countryCode: 'NL',
      discipline: SportDiscipline.football,
      sportType: SportType.football,
      espnSport: 'soccer',
      espnLeague: 'ned.1',
      flashscoreUrl: 'https://www.flashscore.com/football/netherlands/eredivisie/',
    ),
    SportLeague(
      id: 'football_mls',
      name: 'MLS',
      country: 'USA',
      countryCode: 'US',
      discipline: SportDiscipline.football,
      sportType: SportType.football,
      espnSport: 'soccer',
      espnLeague: 'usa.1',
      flashscoreUrl: 'https://www.flashscore.com/football/usa/mls/',
    ),
    SportLeague(
      id: 'football_ekstraklasa',
      name: 'Ekstraklasa',
      country: 'Polska',
      countryCode: 'PL',
      discipline: SportDiscipline.football,
      sportType: SportType.football,
      espnSport: 'soccer',
      espnLeague: 'pol.1',
      tsdbLeagueId: '4422',
      flashscoreUrl: 'https://www.flashscore.com/football/poland/ekstraklasa/',
    ),
    SportLeague(
      id: 'football_champions_league',
      name: 'Liga Mistrzów',
      country: 'Europa',
      countryCode: 'EU',
      discipline: SportDiscipline.football,
      sportType: SportType.football,
      espnSport: 'soccer',
      espnLeague: 'uefa.champions',
      tsdbLeagueId: '4480',
      flashscoreUrl: 'https://www.flashscore.com/football/europe/champions-league/',
    ),
    SportLeague(
      id: 'football_europa_league',
      name: 'Liga Europy',
      country: 'Europa',
      countryCode: 'EU',
      discipline: SportDiscipline.football,
      sportType: SportType.football,
      espnSport: 'soccer',
      espnLeague: 'uefa.europa',
      flashscoreUrl: 'https://www.flashscore.com/football/europe/europa-league/',
    ),

    // ─── KOSZYKÓWKA ───
    SportLeague(
      id: 'basketball_nba',
      name: 'NBA',
      country: 'USA',
      countryCode: 'US',
      discipline: SportDiscipline.basketball,
      sportType: SportType.nba,
      espnSport: 'basketball',
      espnLeague: 'nba',
      flashscoreUrl: 'https://www.flashscore.com/basketball/usa/nba/',
    ),
    SportLeague(
      id: 'basketball_euroleague',
      name: 'Euroliga',
      country: 'Europa',
      countryCode: 'EU',
      discipline: SportDiscipline.basketball,
      sportType: SportType.nba, // reuse MatchEvent
      espnSport: 'basketball',
      espnLeague: 'eur.euroliga',
      flashscoreUrl: 'https://www.flashscore.com/basketball/europe/euroleague/',
    ),
    SportLeague(
      id: 'basketball_plk',
      name: 'PLK',
      country: 'Polska',
      countryCode: 'PL',
      discipline: SportDiscipline.basketball,
      sportType: SportType.nba,
      flashscoreUrl: 'https://www.flashscore.com/basketball/poland/plk/',
    ),

    // ─── HOKEJ ───
    SportLeague(
      id: 'hockey_nhl',
      name: 'NHL',
      country: 'USA/Kanada',
      countryCode: 'US',
      discipline: SportDiscipline.hockey,
      sportType: SportType.nhl,
      espnSport: 'hockey',
      espnLeague: 'nhl',
      flashscoreUrl: 'https://www.flashscore.com/hockey/usa/nhl/',
    ),

    // ─── SIATKÓWKA ───
    SportLeague(
      id: 'volleyball_plus_liga',
      name: 'PlusLiga',
      country: 'Polska',
      countryCode: 'PL',
      discipline: SportDiscipline.volleyball,
      sportType: SportType.volleyball,
      flashscoreUrl: 'https://www.flashscore.com/volleyball/poland/plusliga/',
    ),

    // ─── PIŁKA RĘCZNA ───
    SportLeague(
      id: 'handball_best',
      name: 'Bundesliga (piłka ręczna)',
      country: 'Niemcy',
      countryCode: 'DE',
      discipline: SportDiscipline.handball,
      sportType: SportType.handball,
      espnSport: 'handball',
      espnLeague: 'ger.1',
      flashscoreUrl: 'https://www.flashscore.com/handball/germany/bundesliga/',
    ),

    // ─── TENIS ───
    SportLeague(
      id: 'tennis_wta',
      name: 'WTA',
      country: 'Świat',
      countryCode: 'WORLD',
      discipline: SportDiscipline.tennis,
      sportType: SportType.tennis,
      flashscoreUrl: 'https://www.flashscore.com/tennis/wta-singles/',
    ),
    SportLeague(
      id: 'tennis_atp',
      name: 'ATP',
      country: 'Świat',
      countryCode: 'WORLD',
      discipline: SportDiscipline.tennis,
      sportType: SportType.tennis,
      flashscoreUrl: 'https://www.flashscore.com/tennis/atp-singles/',
    ),

    // ─── F1 ───
    SportLeague(
      id: 'f1',
      name: 'Formula 1',
      country: 'Świat',
      countryCode: 'WORLD',
      discipline: SportDiscipline.f1,
      sportType: SportType.f1,
      flashscoreUrl: 'https://www.flashscore.com/auto-racing/formula-1/',
    ),

    // ─── WRC ───
    SportLeague(
      id: 'wrc',
      name: 'WRC',
      country: 'Świat',
      countryCode: 'WORLD',
      discipline: SportDiscipline.wrc,
      sportType: SportType.wrc,
      flashscoreUrl: 'https://www.flashscore.com/auto-racing/wrc/',
    ),

    // ─── NFL ───
    SportLeague(
      id: 'nfl',
      name: 'NFL',
      country: 'USA',
      countryCode: 'US',
      discipline: SportDiscipline.nfl,
      sportType: SportType.nfl,
      espnSport: 'football',
      espnLeague: 'nfl',
      flashscoreUrl: 'https://www.flashscore.com/football/usa/nfl/',
    ),

    // ─── MLB ───
    SportLeague(
      id: 'mlb',
      name: 'MLB',
      country: 'USA',
      countryCode: 'US',
      discipline: SportDiscipline.mlb,
      sportType: SportType.mlb,
      espnSport: 'baseball',
      espnLeague: 'mlb',
      flashscoreUrl: 'https://www.flashscore.com/baseball/usa/mlb/',
    ),
  ];

  /// Zwraca ligi dla danej dyscypliny
  static List<SportLeague> forDiscipline(SportDiscipline d) =>
      allLeagues.where((l) => l.discipline == d).toList();

  /// Zwraca ligę po ID
  static SportLeague? findById(String id) {
    try {
      return allLeagues.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

}
