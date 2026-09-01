import 'package:hive_flutter/hive_flutter.dart';
import 'package:prasowka/models/article.dart';

class UserInterestService {
  static const String interestsBoxName = 'user_interests';
  final Map<String, double> _scoreCache = {};
  static const int _scoreCacheLimit = 500;

  /// Cache mapy interests — allow batch preloading before scoring loops.
  Map<String, double>? _interestsSnapshot;

  Future<void> init() async {
    if (!Hive.isBoxOpen(interestsBoxName)) {
      await Hive.openBox<double>(interestsBoxName);
    }
  }

  /// Pre-load entire interests box into memory. Call before scoring loops
  /// to avoid thousands of individual Hive reads.
  void preloadInterests() {
    final box = Hive.box<double>(interestsBoxName);
    _interestsSnapshot = Map<String, double>.from(box.toMap());
  }

  /// Clear the in-memory snapshot. Call after mutations.
  void invalidateSnapshot() {
    _interestsSnapshot = null;
  }

  Future<void> processInteraction(Article article, double weight) async {
    final box = Hive.box<double>(interestsBoxName);
    final tags = article.tags;

    final updates = <String, double>{};
    for (var tag in tags) {
      final currentScore = box.get(tag, defaultValue: 0.0) ?? 0.0;
      updates[tag] = currentScore + weight;
    }
    await box.putAll(updates);
    invalidateSnapshot();
    _invalidateCache(article);
  }

  double calculateScore(Article article) {
    if (_scoreCache.containsKey(article.id)) return _scoreCache[article.id]!;
    
    final interests = _interestsSnapshot ?? Map<String, double>.from(
      Hive.box<double>(interestsBoxName).toMap(),
    );
    final tags = article.tags;
    double score = 0.0;

    for (var tag in tags) {
      score += interests[tag] ?? 0.0;
    }
    _scoreCache[article.id] = score;
    if (_scoreCache.length > _scoreCacheLimit) {
      _scoreCache.remove(_scoreCache.keys.first);
    }
    return score;
  }

  void _invalidateCache(Article article) {
    _scoreCache.remove(article.id);
  }

  void clearScoreCache() {
    _scoreCache.clear();
  }
}
