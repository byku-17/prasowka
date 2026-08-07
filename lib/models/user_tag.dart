import 'package:flutter/material.dart';

class UserTag {
  final String id;
  final String name;
  final int colorValue;
  final int iconCodePoint;

  UserTag({
    required this.id,
    required this.name,
    this.colorValue = 0xFFF5B942,
    this.iconCodePoint = 0xe559, // Icons.label
  });

  Color get color => Color(colorValue);
  // ignore: non_const_argument_for_const_parameter
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'iconCodePoint': iconCodePoint,
  };

  factory UserTag.fromMap(Map<String, dynamic> m) => UserTag(
    id: m['id'] ?? '',
    name: m['name'] ?? '',
    colorValue: m['colorValue'] ?? 0xFFF5B942,
    iconCodePoint: m['iconCodePoint'] ?? 0xe559, // Icons.label
  );

  static List<UserTag> defaultTags() => [
    UserTag(id: 'to_read', name: 'Do przeczytania', colorValue: 0xFF4CAF50, iconCodePoint: 0xe550), // bookmark
    UserTag(id: 'important', name: 'Ważne', colorValue: 0xFFF44336, iconCodePoint: 0xe563), // priority_high
    UserTag(id: 'inspiration', name: 'Inspiracja', colorValue: 0xFF9C27B0, iconCodePoint: 0xe80e), // lightbulb
  ];
}
