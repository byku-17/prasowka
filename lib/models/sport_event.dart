enum SportType { football, nba, f1, tennis, volleyball, handball, nhl, mlb, nfl, wrc }

enum EventStatus { live, finished, scheduled }

enum DataFreshness { fresh, cached, stale, unavailable }

abstract class SportEvent {
  final String id;
  final SportType type;
  final DateTime date;
  final EventStatus status;

  SportEvent({
    required this.id,
    required this.type,
    required this.date,
    required this.status,
  });

  Map<String, dynamic> toMap();

  static SportEvent fromMap(Map m) {
    if (m['kind'] == 'match') return MatchEvent.fromMap(m);
    if (m['kind'] == 'race') return RaceEvent.fromMap(m);
    throw ArgumentError('Unknown SportEvent kind: ${m['kind']}');
  }
}

class MatchEvent extends SportEvent {
  final String homeTeam;
  final String awayTeam;
  final String? homeLogo;
  final String? awayLogo;
  final String score;
  final String? time;
  final String competition;
  final DataFreshness freshness;
  final DateTime? fetchedAtUtc;

  MatchEvent({
    required super.id,
    required super.type,
    required super.date,
    required super.status,
    required this.homeTeam,
    required this.awayTeam,
    required this.score,
    required this.competition,
    this.homeLogo,
    this.awayLogo,
    this.time,
    this.freshness = DataFreshness.fresh,
    this.fetchedAtUtc,
  });

  @override
  Map<String, dynamic> toMap() => {
    'kind': 'match',
    'id': id,
    'type': type.name,
    'date': date.toIso8601String(),
    'status': status.name,
    'homeTeam': homeTeam,
    'awayTeam': awayTeam,
    'homeLogo': homeLogo,
    'awayLogo': awayLogo,
    'score': score,
    'time': time,
    'competition': competition,
    'freshness': freshness.name,
    'fetchedAtUtc': fetchedAtUtc?.toIso8601String(),
  };

  factory MatchEvent.fromMap(Map m) => MatchEvent(
    id: m['id'],
    type: SportType.values.firstWhere((e) => e.name == m['type']),
    date: DateTime.parse(m['date']),
    status: EventStatus.values.firstWhere((e) => e.name == m['status']),
    homeTeam: m['homeTeam'],
    awayTeam: m['awayTeam'],
    score: m['score'],
    competition: m['competition'],
    homeLogo: m['homeLogo'],
    awayLogo: m['awayLogo'],
    time: m['time'],
    freshness: DataFreshness.values.firstWhere((e) => e.name == (m['freshness'] ?? 'fresh')),
    fetchedAtUtc: m['fetchedAtUtc'] != null ? DateTime.tryParse(m['fetchedAtUtc']) : null,
  );
}

class RaceEvent extends SportEvent {
  final String raceName;
  final String circuitName;
  final String countryCode;
  final List<String> results;

  RaceEvent({
    required super.id,
    required super.type,
    required super.date,
    required super.status,
    required this.raceName,
    required this.circuitName,
    required this.countryCode,
    this.results = const [],
  });

  @override
  Map<String, dynamic> toMap() => {
    'kind': 'race',
    'id': id,
    'type': type.name,
    'date': date.toIso8601String(),
    'status': status.name,
    'raceName': raceName,
    'circuitName': circuitName,
    'countryCode': countryCode,
    'results': results,
  };

  factory RaceEvent.fromMap(Map m) => RaceEvent(
    id: m['id'],
    type: SportType.values.firstWhere((e) => e.name == m['type']),
    date: DateTime.parse(m['date']),
    status: EventStatus.values.firstWhere((e) => e.name == m['status']),
    raceName: m['raceName'],
    circuitName: m['circuitName'],
    countryCode: m['countryCode'],
    results: List<String>.from(m['results'] ?? []),
  );
}

class MatchStatRow {
  final String label;
  final String homeValue;
  final String awayValue;
  const MatchStatRow({required this.label, required this.homeValue, required this.awayValue});
}

class MatchStats {
  final String header;
  final List<MatchStatRow> rows;
  const MatchStats({required this.header, required this.rows});
}
