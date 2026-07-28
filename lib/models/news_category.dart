import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'news_category.g.dart';

@HiveType(typeId: 2)
class NewsCategory extends HiveObject {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final int iconCode; // Zapisujemy kod ikony, bo IconData nie jest wspierane bezpośrednio przez Hive

  @HiveField(3)
  final bool isCustom; // Czy kategoria została dodana przez użytkownika

  NewsCategory({
    required this.id,
    required this.name,
    required this.iconCode,
    this.isCustom = false,
  });

  // Pomocniczy getter do pobierania IconData
  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');

  static final List<NewsCategory> defaultCategories = [
    NewsCategory(id: 'all', name: 'Wszystkie', iconCode: Icons.auto_awesome.codePoint),
    NewsCategory(id: 'world', name: 'Świat', iconCode: Icons.public.codePoint),
    NewsCategory(id: 'poland', name: 'Polska', iconCode: Icons.flag.codePoint),
    NewsCategory(id: 'business', name: 'Biznes', iconCode: Icons.business_center.codePoint),
    NewsCategory(id: 'sport', name: 'Sport', iconCode: Icons.sports_soccer.codePoint),
    NewsCategory(id: 'tech', name: 'Tech', iconCode: Icons.computer.codePoint),
    NewsCategory(id: 'science', name: 'Nauka', iconCode: Icons.science.codePoint),
    NewsCategory(id: 'automotive', name: 'Motoryzacja', iconCode: Icons.directions_car.codePoint),
    NewsCategory(id: 'travel', name: 'Podróże', iconCode: Icons.flight_takeoff.codePoint),
    NewsCategory(id: 'deals', name: 'Promocje', iconCode: Icons.local_offer.codePoint),
    NewsCategory(id: 'lifestyle', name: 'Lifestyle', iconCode: Icons.style.codePoint),
    NewsCategory(id: 'culture', name: 'Kultura', iconCode: Icons.theater_comedy.codePoint),
    NewsCategory(id: 'warsaw', name: 'Warszawa', iconCode: Icons.location_city.codePoint),
    NewsCategory(id: 'api_news', name: 'API News', iconCode: Icons.api.codePoint),
  ];
}
