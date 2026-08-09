import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prasowka/services/auth_service.dart';
import 'package:prasowka/services/encryption_service.dart';

class SyncService extends ChangeNotifier {
  static const String scopeSettings = 'settings';
  static const String scopeTags = 'tags';
  static const String scopeArticles = 'articles';
  static const String scopeInterests = 'interests';
  static const String scopeCategories = 'categories';
  static const String scopeSources = 'sources';
  static const String scopeReading = 'reading';
  static const String scopePinned = 'pinned';
  static const Set<String> allScopes = {
    scopeSettings, scopeTags, scopeArticles, scopeInterests,
    scopeCategories, scopeSources, scopeReading, scopePinned,
  };
  static const String syncScopeKey = 'syncScope';

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _auth;
  final EncryptionService _encryption = EncryptionService();
  
  DateTime? _lastSync;
  DateTime? get lastSync => _lastSync;
  String? _encryptionPassword;

  SyncService(this._auth);

  void setEncryptionPassword(String password) {
    _encryptionPassword = password;
  }

  String? get _uid => _auth.user?.uid;

  /// Które zakresy danych mają być synchronizowane.
  Set<String> _getSyncScope() {
    if (!Hive.isBoxOpen('settings')) return allScopes;
    final stored = Hive.box('settings').get(syncScopeKey);
    if (stored is List && stored.isNotEmpty) return stored.cast<String>().toSet();
    return allScopes;
  }

  CollectionReference<Map<String, dynamic>> _userDoc(String collection) =>
      _db.collection('users').doc(_uid!).collection(collection);

  // ─── PUSH: Hive → Firestore ───

  Future<void> pushAll() async {
    if (_uid == null) return;
    notifyListeners();

    try {
      final scope = _getSyncScope();
      final futures = <Future<void>>[];
      if (scope.contains(scopeSettings)) futures.add(_pushSettings());
      if (scope.contains(scopeTags)) futures.add(_pushTags());
      if (scope.contains(scopeArticles)) futures.add(_pushArticles());
      if (scope.contains(scopeInterests)) futures.add(_pushInterests());
      if (scope.contains(scopeCategories)) futures.add(_pushCategories());
      if (scope.contains(scopeSources)) futures.add(_pushSources());
      if (scope.contains(scopeReading)) futures.add(_pushReadingHistory());
      if (scope.contains(scopePinned)) futures.add(_pushPinnedMatches());
      await Future.wait(futures);
      _lastSync = DateTime.now();
      debugPrint('Sync: push complete (${futures.length} zakresów)');
    } catch (e) {
      debugPrint('Sync push error: $e');
    }

    notifyListeners();
  }

  // ─── PULL: Firestore → Hive ───

  Future<void> pullAll() async {
    if (_uid == null) return;
    notifyListeners();

    try {
      final scope = _getSyncScope();
      final futures = <Future<void>>[];
      if (scope.contains(scopeSettings)) futures.add(_pullSettings());
      if (scope.contains(scopeTags)) futures.add(_pullTags());
      if (scope.contains(scopeArticles)) futures.add(_pullArticles());
      if (scope.contains(scopeInterests)) futures.add(_pullInterests());
      if (scope.contains(scopeCategories)) futures.add(_pullCategories());
      if (scope.contains(scopeSources)) futures.add(_pullSources());
      if (scope.contains(scopeReading)) futures.add(_pullReadingHistory());
      if (scope.contains(scopePinned)) futures.add(_pullPinnedMatches());
      await Future.wait(futures);
      _lastSync = DateTime.now();
      debugPrint('Sync: pull complete (${futures.length} zakresów)');
    } catch (e) {
      debugPrint('Sync pull error: $e');
    }

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
    // NIE nadpisujemy localnych ustawień z Firestore
    // Ustawienia są zawsze local-first
    debugPrint('Sync: _pullSettings skipped (local-first mode)');
    return;
  }

  // ─── TAGS (encrypted) ───

  Future<void> _pushTags() async {
    final box = Hive.box('user_tags');
    final data = <String, dynamic>{};
    for (final key in box.keys) {
      data[key.toString()] = box.get(key);
    }
    if (_encryptionPassword != null && data.isNotEmpty) {
      final encrypted = await _encryption.encryptMap(data, _uid!, _encryptionPassword!);
      await _userDoc('tags_encrypted').doc('data').set({'payload': encrypted});
    } else if (data.isNotEmpty) {
      final batch = _db.batch();
      for (final entry in data.entries) {
        batch.set(_userDoc('tags').doc(entry.key), Map<String, dynamic>.from(entry.value is Map ? entry.value : {'value': entry.value}));
      }
      await batch.commit();
    }
  }

  Future<void> _pullTags() async {
    final box = Hive.box('user_tags');
    if (_encryptionPassword != null) {
      final doc = await _userDoc('tags_encrypted').doc('data').get();
      if (!doc.exists) return;
      final decrypted = await _encryption.decryptMap(doc.data()!['payload'], _uid!, _encryptionPassword!);
      for (final entry in decrypted.entries) {
        if (!box.containsKey(entry.key)) {
          await box.put(entry.key, entry.value);
        }
      }
    } else {
      final snapshot = await _userDoc('tags').get();
      for (final doc in snapshot.docs) {
        if (!box.containsKey(doc.id)) {
          await box.put(doc.id, doc.data());
        }
      }
    }
  }

  // ─── ARTICLES (encrypted) ───

  Future<void> _pushArticles() async {
    final box = Hive.box('articles');
    final data = <String, dynamic>{};
    for (final key in box.keys) {
      final article = box.get(key);
      if (article == null) continue;
      data[key.toString()] = {
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
    }
    if (_encryptionPassword != null && data.isNotEmpty) {
      final encrypted = await _encryption.encryptMap(data, _uid!, _encryptionPassword!);
      await _userDoc('articles_encrypted').doc('data').set({'payload': encrypted});
    } else if (data.isNotEmpty) {
      final batch = _db.batch();
      for (final entry in data.entries) {
        batch.set(_userDoc('articles').doc(entry.key), entry.value);
      }
      await batch.commit();
    }
  }

  Future<void> _pullArticles() async {
    final box = Hive.box('articles');
    Map<String, dynamic> dataMap = {};

    if (_encryptionPassword != null) {
      final doc = await _userDoc('articles_encrypted').doc('data').get();
      if (!doc.exists) return;
      dataMap = await _encryption.decryptMap(doc.data()!['payload'], _uid!, _encryptionPassword!);
    } else {
      final snapshot = await _userDoc('articles').get();
      for (final doc in snapshot.docs) {
        dataMap[doc.id] = doc.data();
      }
    }

    for (final entry in dataMap.entries) {
      final data = entry.value;
      final existing = box.get(entry.key);
      if (existing != null) {
        existing.isSaved = data['isSaved'] ?? existing.isSaved;
        existing.isLiked = data['isLiked'] ?? existing.isLiked;
        existing.isDisliked = data['isDisliked'] ?? existing.isDisliked;
        existing.tagIds = List<String>.from(data['tagIds'] ?? existing.tagIds);
        existing.isRead = data['isRead'] ?? existing.isRead;
        await existing.save();
      } else {
        debugPrint('Sync: article ${entry.key} not in local cache, skipping');
      }
    }
  }

  // ─── INTERESTS (encrypted) ───

  Future<void> _pushInterests() async {
    final box = Hive.box('user_interests');
    final data = Map<String, dynamic>.from(box.toMap());
    if (_encryptionPassword != null && data.isNotEmpty) {
      final encrypted = await _encryption.encryptMap(data, _uid!, _encryptionPassword!);
      await _userDoc('interests_encrypted').doc('data').set({'payload': encrypted});
    } else if (data.isNotEmpty) {
      await _userDoc('interests').doc('scores').set(data, SetOptions(merge: true));
    }
  }

  Future<void> _pullInterests() async {
    final box = Hive.box('user_interests');
    if (_encryptionPassword != null) {
      final doc = await _userDoc('interests_encrypted').doc('data').get();
      if (!doc.exists) return;
      final decrypted = await _encryption.decryptMap(doc.data()!['payload'], _uid!, _encryptionPassword!);
      for (final entry in decrypted.entries) {
        if (entry.value is num && !box.containsKey(entry.key)) {
          await box.put(entry.key, (entry.value as num).toDouble());
        }
      }
    } else {
      final doc = await _userDoc('interests').doc('scores').get();
      if (!doc.exists) return;
      final data = doc.data()!;
      for (final entry in data.entries) {
        if (entry.value is num && !box.containsKey(entry.key)) {
          await box.put(entry.key, (entry.value as num).toDouble());
        }
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

  // ─── READING HISTORY (encrypted) ───

  Future<void> _pushReadingHistory() async {
    final box = Hive.box('reading_history');
    final data = <String, dynamic>{};
    for (final key in box.keys) {
      final entry = box.get(key);
      if (entry != null) {
        data[key.toString()] = entry;
      }
    }
    if (_encryptionPassword != null && data.isNotEmpty) {
      final encrypted = await _encryption.encryptMap(data, _uid!, _encryptionPassword!);
      await _userDoc('reading_history_encrypted').doc('data').set({'payload': encrypted});
    } else if (data.isNotEmpty) {
      final batch = _db.batch();
      for (final entry in data.entries) {
        batch.set(_userDoc('reading_history').doc(entry.key), entry.value);
      }
      await batch.commit();
    }
  }

  Future<void> _pullReadingHistory() async {
    final box = Hive.box('reading_history');
    if (_encryptionPassword != null) {
      final doc = await _userDoc('reading_history_encrypted').doc('data').get();
      if (!doc.exists) return;
      final decrypted = await _encryption.decryptMap(doc.data()!['payload'], _uid!, _encryptionPassword!);
      for (final entry in decrypted.entries) {
        if (!box.containsKey(entry.key)) {
          await box.put(entry.key, entry.value);
        }
      }
    } else {
      final snapshot = await _userDoc('reading_history').get();
      for (final doc in snapshot.docs) {
        if (!box.containsKey(doc.id)) {
          await box.put(doc.id, doc.data());
        }
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
      if (!box.containsKey(entry.key)) {
        await box.put(entry.key, entry.value);
      }
    }
  }
}
