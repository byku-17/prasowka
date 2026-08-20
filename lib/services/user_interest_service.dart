import 'package:hive_flutter/hive_flutter.dart';
import 'package:prasowka/models/article.dart';

class UserInterestService {
  static const String interestsBoxName = 'user_interests';
  final Map<String, double> _scoreCache = {};

  Future<void> init() async {
    if (!Hive.isBoxOpen(interestsBoxName)) {
      await Hive.openBox<double>(interestsBoxName);
    }
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
    _invalidateCache(article);
  }

  double calculateScore(Article article) {
    if (_scoreCache.containsKey(article.id)) return _scoreCache[article.id]!;
    
    final box = Hive.box<double>(interestsBoxName);
    final tags = article.tags;
    double score = 0.0;

    for (var tag in tags) {
      score += box.get(tag, defaultValue: 0.0) ?? 0.0;
    }
    _scoreCache[article.id] = score;
    return score;
  }

  void _invalidateCache(Article article) {
    _scoreCache.remove(article.id);
  }

  /// Czyści cache score'ów dla WSZYSTKICH artykułów. Wymagane po każdej
  /// zmianie zainteresowań — wagi tagów się zmieniły, więc wszystkie
  /// zapamiętane score'y są nieaktualne.
  void clearScoreCache() {
    _scoreCache.clear();
  }
}
