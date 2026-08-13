import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prasowka/models/user_tag.dart';

class TagProvider with ChangeNotifier {
  static const String boxName = 'user_tags';
  List<UserTag> _tags = [];

  List<UserTag> get tags => List.unmodifiable(_tags);

  Future<void> init() async {
    final box = await Hive.openBox(boxName);
    if (box.isEmpty) {
      for (final tag in UserTag.defaultTags()) {
        await box.put(tag.id, tag.toMap());
      }
    }
    _reload(box);
  }

  void _reload(Box box) {
    _tags = box.values.map((e) => UserTag.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  UserTag? getById(String id) {
    try {
      return _tags.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addTag(String name, {Color? color, IconData? icon}) async {
    final box = Hive.box(boxName);
    final id = 'tag_${DateTime.now().millisecondsSinceEpoch}';
    final tag = UserTag(
      id: id,
      name: name,
      colorValue: color?.toARGB32() ?? 0xFFF5B942,
      iconCodePoint: icon?.codePoint ?? Icons.label.codePoint,
    );
    await box.put(id, tag.toMap());
    _reload(box);
    notifyListeners();
  }

  Future<void> updateTag(String id, {String? name, Color? color, IconData? icon}) async {
    final box = Hive.box(boxName);
    final existing = box.get(id);
    if (existing == null) return;
    final old = UserTag.fromMap(Map<String, dynamic>.from(existing));
    final updated = UserTag(
      id: id,
      name: name ?? old.name,
      colorValue: color?.toARGB32() ?? old.colorValue,
      iconCodePoint: icon?.codePoint ?? old.iconCodePoint,
    );
    await box.put(id, updated.toMap());
    _reload(box);
    notifyListeners();
  }

  Future<void> removeTag(String id) async {
    final box = Hive.box(boxName);
    await box.delete(id);
    _reload(box);
    notifyListeners();
  }
}
