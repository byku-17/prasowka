import 'package:flutter/material.dart';

/// Reprezentuje kategorię newsów w aplikacji.
class NewsCategory {
  final String id;
  final String name;
  final IconData icon;

  const NewsCategory({
    required this.id,
    required this.name,
    required this.icon,
  });

  /// Statyczna lista domyślnych kategorii
  static List<NewsCategory> get defaultCategories => [
    const NewsCategory(id: 'world', name: 'Świat', icon: Icons.public),
    const NewsCategory(id: 'poland', name: 'Polska', icon: Icons.flag),
    const NewsCategory(id: 'business', name: 'Biznes', icon: Icons.business_center),
    const NewsCategory(id: 'sport', name: 'Sport', icon: Icons.sports_soccer),
    const NewsCategory(id: 'tech', name: 'Tech', icon: Icons.computer),
    const NewsCategory(id: 'culture', name: 'Kultura', icon: Icons.theater_comedy),
  ];
}
