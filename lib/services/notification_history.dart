import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class NotificationEntry {
  final String id;
  final String title;
  final String body;
  final String? url;
  final DateTime timestamp;
  final String type; // 'article' | 'sport'
  bool isRead;

  NotificationEntry({
    required this.id,
    required this.title,
    required this.body,
    this.url,
    required this.timestamp,
    required this.type,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'url': url,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'type': type,
    'isRead': isRead,
  };

  factory NotificationEntry.fromMap(Map map) => NotificationEntry(
    id: map['id'] ?? '',
    title: map['title'] ?? '',
    body: map['body'] ?? '',
    url: map['url'],
    timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
    type: map['type'] ?? 'article',
    isRead: map['isRead'] ?? false,
  );
}

class NotificationHistory {
  static final NotificationHistory _instance = NotificationHistory._internal();
  factory NotificationHistory() => _instance;
  NotificationHistory._internal();

  static const String _boxName = 'notification_history';
  static const int _maxEntries = 100;

  Box<Map>? _box;

  Future<void> init() async {
    try {
      _box = await Hive.openBox<Map>(_boxName);
    } catch (e) {
      debugPrint('Sowa Notyfikacje: Błąd inicjalizacji historii: $e');
    }
  }

  Box<Map> get box {
    if (_box == null || !_box!.isOpen) {
      throw StateError('NotificationHistory not initialized');
    }
    return _box!;
  }

  Future<void> add(NotificationEntry entry) async {
    try {
      await box.put(entry.id, entry.toMap());
      // Ogranicz historię do _maxEntries — usuwaj NAJSTARSZE wpisy
      if (box.length > _maxEntries) {
        final entries = all; // sortowane po timestamp malejąco
        final toDelete = entries.sublist(_maxEntries); // najstarsze do usunięcia
        for (var e in toDelete) {
          await box.delete(e.id);
        }
      }
    } catch (e) {
      debugPrint('Sowa Notyfikacje: Błąd zapisu: $e');
    }
  }

  List<NotificationEntry> get all {
    final entries = box.values.map((m) => NotificationEntry.fromMap(m)).toList();
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  int get unreadCount {
    return all.where((e) => !e.isRead).length;
  }

  Future<void> markAllRead() async {
    for (var key in box.keys) {
      final map = box.get(key);
      if (map != null && map['isRead'] == false) {
        map['isRead'] = true;
        await box.put(key, map);
      }
    }
  }

  Future<void> clear() async {
    await box.clear();
  }
}
