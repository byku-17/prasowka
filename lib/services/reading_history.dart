import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';

class HistoryEntry {
  final String id;
  final String title;
  final String? description;
  final String url;
  final String? imageUrl;
  final String sourceName;
  final DateTime publishedAt;
  final DateTime openedAt;
  final int readSeconds;

  HistoryEntry({
    required this.id,
    required this.title,
    this.description,
    required this.url,
    this.imageUrl,
    required this.sourceName,
    required this.publishedAt,
    required this.openedAt,
    this.readSeconds = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'url': url,
    'imageUrl': imageUrl,
    'sourceName': sourceName,
    'publishedAt': publishedAt.toIso8601String(),
    'openedAt': openedAt.toIso8601String(),
    'readSeconds': readSeconds,
  };

  factory HistoryEntry.fromMap(Map m) => HistoryEntry(
    id: m['id'] ?? '',
    title: m['title'] ?? '',
    description: m['description'],
    url: m['url'] ?? '',
    imageUrl: m['imageUrl'],
    sourceName: m['sourceName'] ?? '',
    publishedAt: DateTime.tryParse(m['publishedAt'] ?? '') ?? DateTime.now(),
    openedAt: DateTime.tryParse(m['openedAt'] ?? '') ?? DateTime.now(),
    readSeconds: m['readSeconds'] ?? 0,
  );
}

class ReadingHistory {
  static final ReadingHistory _instance = ReadingHistory._();
  factory ReadingHistory() => _instance;
  ReadingHistory._();

  static const String _boxName = 'reading_history';
  static const int _maxEntries = 200;
  Box<Map>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<Map>(_boxName);
  }

  Future<void> add({
    required String id,
    required String title,
    String? description,
    required String url,
    String? imageUrl,
    required String sourceName,
    required DateTime publishedAt,
    int readSeconds = 0,
  }) async {
    if (_box == null) return;
    final entry = HistoryEntry(
      id: id,
      title: title,
      description: description,
      url: url,
      imageUrl: imageUrl,
      sourceName: sourceName,
      publishedAt: publishedAt,
      openedAt: DateTime.now(),
      readSeconds: readSeconds,
    );
    await _box!.put(id, entry.toMap());

    // Usuń najstarsze wpisy jeśli przekroczono limit
    if (_box!.length > _maxEntries) {
      final keys = _box!.keys.toList();
      final sorted = keys.map((k) {
        final m = _box!.get(k);
        return MapEntry(k, DateTime.tryParse(m?['openedAt'] ?? '') ?? DateTime(2000));
      }).toList()..sort((a, b) => a.value.compareTo(b.value));
      final toRemove = sorted.take(_box!.length - _maxEntries).map((e) => e.key).toList();
      await _box!.deleteAll(toRemove);
    }
  }

  List<HistoryEntry> getAll() {
    if (_box == null) return [];
    final entries = _box!.values.map((m) => HistoryEntry.fromMap(m)).toList();
    entries.sort((a, b) => b.openedAt.compareTo(a.openedAt));
    return entries;
  }

  Future<void> delete(String id) async {
    await _box?.delete(id);
  }

  Future<void> clear() async {
    await _box?.clear();
  }

  int get count => _box?.length ?? 0;
}
