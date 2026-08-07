import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prasowka/services/auth_service.dart';

class SyncService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _auth;
  
  bool _syncing = false;
  bool get syncing => _syncing;
  DateTime? _lastSync;
  DateTime? get lastSync => _lastSync;

  SyncService(this._auth);

  String? get _uid => _auth.user?.uid;

  CollectionReference<Map<String, dynamic>> _userDoc(String collection) =>
      _db.collection('users').doc(_uid!).collection(collection);

  // ─── PUSH: Hive → Firestore ───

  Future<void> pushAll() async {
    if (_uid == null) return;
    _syncing = true;
    notifyListeners();

    try {
      await Future.wait([
        _pushSettings(),
        _pushTags(),
        _pushArticles(),
        _pushInterests(),
        _pushCategories(),
        _pushSources(),
        _pushReadingHistory(),
        _pushPinnedMatches(),
      ]);
      _lastSync = DateTime.now();
      debugPrint('Sync: push complete');
    } catch (e) {
      debugPrint('Sync push error: $e');
    }

    _syncing = false;
    notifyListeners();
  }

  // ─── PULL: Firestore → Hive ───

  Future<void> pullAll() async {
    if (_uid == null) return;
    _syncing = true;
    notifyListeners();

    try {
      await Future.wait([
        _pullSettings(),
        _pullTags(),
        _pullArticles(),
        _pullInterests(),
        _pullCategories(),
        _pullSources(),
        _pullReadingHistory(),
        _pullPinnedMatches(),
      ]);
      _lastSync = DateTime.now();
      debugPrint('Sync: pull complete');
    } catch (e) {
      debugPrint('Sync pull error: $e');
    }

    _syncing = false;
    notifyListeners();
  }

  // ─── MERGE: push → pull (first login) ───

  Future<void> mergeFirstLogin() async {
    if (_uid == null) return;
    
    final hasRemoteData = await _checkRemoteData();
    if (hasRemoteData) {
      await pullAll();
    } else {
      await pushAll();
    }
  }

  Future<bool> _checkRemoteData() async {
    final snapshot = await _userDoc('settings').limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  // ─── SETTINGS ───

  Future<void> _pushSettings() async {
    final box = Hive.box('settings');
    final data = Map<String, dynamic>.from(box.toMap());
    await _userDoc('settings').doc('main').set(data, SetOptions(merge: true));
  }

  Future<void> _pullSettings() async {
    final doc = await _userDoc('settings').doc('main').get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final box = Hive.box('settings');
    for (final entry in data.entries) {
      await box.put(entry.key, entry.value);
    }
  }

  // ─── TAGS ───

  Future<void> _pushTags() async {
    final box = Hive.box('user_tags');
    final batch = _db.batch();
    for (final key in box.keys) {
      final value = box.get(key);
      batch.set(_userDoc('tags').doc(key.toString()), Map<String, dynamic>.from(value is Map ? value : {'value': value}));
    }
    await batch.commit();
  }

  Future<void> _pullTags() async {
    final snapshot = await _userDoc('tags').get();
    final box = Hive.box('user_tags');
    for (final doc in snapshot.docs) {
      await box.put(doc.id, doc.data());
    }
  }

  // ─── ARTICLES ───

  Future<void> _pushArticles() async {
    final box = Hive.box('articles');
    final batch = _db.batch();
    for (final key in box.keys) {
      final article = box.get(key);
      if (article == null) continue;
      final data = {
        'id': article.id,
        'title': article.title,
        'description': article.description,
        'content': article.content,
        'url': article.url,
        'imageUrl': article.imageUrl,
        'sourceName': article.sourceName,
        'publishedAt': article.publishedAt?.millisecondsSinceEpoch,
        'isSaved': article.isSaved,
        'isLiked': article.isLiked,
        'isDisliked': article.isDisliked,
        'tagIds': article.tagIds,
        'readTimeSeconds': article.readTimeSeconds,
        'isRead': article.isRead,
      };
      batch.set(_userDoc('articles').doc(key.toString()), data);
    }
    await batch.commit();
  }

  Future<void> _pullArticles() async {
    final snapshot = await _userDoc('articles').get();
    final box = Hive.box('articles');
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final existing = box.get(doc.id);
      if (existing != null) {
        existing.isSaved = data['isSaved'] ?? existing.isSaved;
        existing.isLiked = data['isLiked'] ?? existing.isLiked;
        existing.isDisliked = data['isDisliked'] ?? existing.isDisliked;
        existing.tagIds = List<String>.from(data['tagIds'] ?? existing.tagIds);
        existing.isRead = data['isRead'] ?? existing.isRead;
        await existing.save();
      } else {
        debugPrint('Sync: article ${doc.id} not in local cache, skipping');
      }
    }
  }

  // ─── INTERESTS ───

  Future<void> _pushInterests() async {
    final box = Hive.box('user_interests');
    final data = Map<String, dynamic>.from(box.toMap());
    await _userDoc('interests').doc('scores').set(data, SetOptions(merge: true));
  }

  Future<void> _pullInterests() async {
    final doc = await _userDoc('interests').doc('scores').get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final box = Hive.box('user_interests');
    for (final entry in data.entries) {
      if (entry.value is num) {
        await box.put(entry.key, (entry.value as num).toDouble());
      }
    }
  }

  // ─── CATEGORIES ───

  Future<void> _pushCategories() async {
    final box = Hive.box('news_categories_dynamic');
    final batch = _db.batch();
    for (final key in box.keys) {
      final cat = box.get(key);
      if (cat == null) continue;
      final data = {
        'id': cat.id,
        'name': cat.name,
        'iconCode': cat.iconCode,
        'isCustom': cat.isCustom,
      };
      batch.set(_userDoc('categories').doc(key.toString()), data);
    }
    await batch.commit();
  }

  Future<void> _pullCategories() async {
    final snapshot = await _userDoc('categories').get();
    final box = Hive.box('news_categories_dynamic');
    for (final doc in snapshot.docs) {
      if (!box.containsKey(doc.id)) {
        await box.put(doc.id, doc.data());
      }
    }
  }

  // ─── SOURCES ───

  Future<void> _pushSources() async {
    final box = Hive.box('news_sources_dynamic');
    final batch = _db.batch();
    for (final key in box.keys) {
      final src = box.get(key);
      if (src == null) continue;
      final data = {
        'id': src.id,
        'name': src.name,
        'url': src.url,
        'categoryId': src.categoryId,
        'isActive': src.isActive,
      };
      batch.set(_userDoc('sources').doc(key.toString()), data);
    }
    await batch.commit();
  }

  Future<void> _pullSources() async {
    final snapshot = await _userDoc('sources').get();
    final box = Hive.box('news_sources_dynamic');
    for (final doc in snapshot.docs) {
      if (!box.containsKey(doc.id)) {
        await box.put(doc.id, doc.data());
      }
    }
  }

  // ─── READING HISTORY ───

  Future<void> _pushReadingHistory() async {
    final box = Hive.box('reading_history');
    final batch = _db.batch();
    for (final key in box.keys) {
      final entry = box.get(key);
      if (entry == null) continue;
      batch.set(_userDoc('reading_history').doc(key.toString()), Map<String, dynamic>.from(entry is Map ? entry : {'value': entry}));
    }
    await batch.commit();
  }

  Future<void> _pullReadingHistory() async {
    final snapshot = await _userDoc('reading_history').get();
    final box = Hive.box('reading_history');
    for (final doc in snapshot.docs) {
      if (!box.containsKey(doc.id)) {
        await box.put(doc.id, doc.data());
      }
    }
  }

  // ─── PINNED MATCHES ───

  Future<void> _pushPinnedMatches() async {
    final box = Hive.box('pinned_matches');
    final data = Map<String, dynamic>.from(box.toMap());
    await _userDoc('pinned_matches').doc('matches').set(data, SetOptions(merge: true));
  }

  Future<void> _pullPinnedMatches() async {
    final doc = await _userDoc('pinned_matches').doc('matches').get();
    if (!doc.exists) return;
    final data = doc.data()!;
    final box = Hive.box('pinned_matches');
    for (final entry in data.entries) {
      await box.put(entry.key, entry.value);
    }
  }
}
