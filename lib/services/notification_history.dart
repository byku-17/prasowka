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
  int _unreadCount = 0;

  Future<void> init() async {
    try {
      _box = await Hive.openBox<Map>(_boxName);
      await _box!.compact();
      _recountUnread();
    } catch (e) {
      debugPrint('Sowa Notyfikacje: Błąd inicjalizacji historii: $e');
    }
  }

  void _recountUnread() {
    if (_box == null || !_box!.isOpen) { _unreadCount = 0; return; }
    _unreadCount = 0;
    for (var key in _box!.keys) {
      final map = _box!.get(key);
      if (map != null && map['isRead'] != true) _unreadCount++;
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
      if (!entry.isRead) _unreadCount++;
      // Ogranicz historię do _maxEntries — usuwaj NAJSTARSZE wpisy
      if (box.length > _maxEntries) {
        final entries = all; // sortowane po timestamp malejąco
        final toDelete = entries.sublist(_maxEntries); // najstarsze do usunięcia
        for (var e in toDelete) {
          if (!e.isRead) _unreadCount = (_unreadCount - 1).clamp(0, _maxEntries);
          await box.delete(e.id);
        }
      }
    } catch (e) {
      debugPrint('Sowa Notyfikacje: Błąd zapisu: $e');
    }
  }

  List<NotificationEntry> get all {
    _ensureBoxOpen();
    if (_box == null || !_box!.isOpen) return [];
    final entries = _box!.values.map((m) => NotificationEntry.fromMap(m)).toList();
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  int get unreadCount => _unreadCount;

  void _ensureBoxOpen() {
    try {
      if (_box == null || !_box!.isOpen) {
        _box = Hive.box<Map>(_boxName);
      }
    } catch (_) {}
  }

  /// Wymuś ponowne otwarcie boxa (po zmianach z innego izolatu Workmanager)
  Future<void> refreshBox() async {
    try {
      if (_box != null && _box!.isOpen) {
        await _box!.close();
      }
      _box = await Hive.openBox<Map>(_boxName);
      _recountUnread();
    } catch (e) {
      debugPrint('Sowa Notyfikacje: Błąd odświeżania boxa: $e');
    }
  }

  Future<void> markAllRead() async {
    if (_box == null || !_box!.isOpen) return;
    for (var key in _box!.keys) {
      final map = _box!.get(key);
      if (map != null && map['isRead'] == false) {
        map['isRead'] = true;
        await _box!.put(key, map);
      }
    }
    _unreadCount = 0;
  }

  Future<void> markRead(String id) async {
    if (_box == null || !_box!.isOpen) return;
    final map = _box!.get(id);
    if (map != null && map['isRead'] == false) {
      map['isRead'] = true;
      await _box!.put(id, map);
      _unreadCount = (_unreadCount - 1).clamp(0, _maxEntries);
    }
  }

  Future<void> markReadByUrl(String url) async {
    if (_box == null || !_box!.isOpen) return;
    for (var key in _box!.keys) {
      final map = _box!.get(key);
      if (map != null && map['url'] == url && map['isRead'] == false) {
        map['isRead'] = true;
        await _box!.put(key, map);
        _unreadCount = (_unreadCount - 1).clamp(0, _maxEntries);
      }
    }
  }

  Future<void> markUnread(String id) async {
    if (_box == null || !_box!.isOpen) return;
    final map = _box!.get(id);
    if (map != null && map['isRead'] == true) {
      map['isRead'] = false;
      await _box!.put(id, map);
      _unreadCount++;
    }
  }

  Future<void> delete(String id) async {
    if (_box == null || !_box!.isOpen) return;
    final map = _box!.get(id);
    if (map != null && map['isRead'] != true) {
      _unreadCount = (_unreadCount - 1).clamp(0, _maxEntries);
    }
    await _box!.delete(id);
  }

  Future<void> clear() async {
    if (_box == null || !_box!.isOpen) return;
    await _box!.clear();
    _unreadCount = 0;
  }
}
