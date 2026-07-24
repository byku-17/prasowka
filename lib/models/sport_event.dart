import 'package:flutter/material.dart';

enum SportType { football, nba, f1, tennis, volleyball, handball, nhl, mlb, nfl }

enum EventStatus { live, finished, scheduled }

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
}

class MatchEvent extends SportEvent {
  final String homeTeam;
  final String awayTeam;
  final String? homeLogo;
  final String? awayLogo;
  final String score;
  final String? time; // np. 75' lub "Q3"
  final String competition;

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
  });
}

class RaceEvent extends SportEvent {
  final String raceName;
  final String circuitName;
  final String countryCode;
  final List<String> results; // np. podium ["Verstappen", "Norris", "Hamilton"]

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
}
