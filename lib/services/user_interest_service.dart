import 'package:hive_flutter/hive_flutter.dart';
import 'package:prasowka/models/article.dart';

class UserInterestService {
  static const String interestsBoxName = 'user_interests';
  
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
    article.cachedScore = null; // Unieważnij cache po zmianie zainteresowań
  }

  double calculateScore(Article article) {
    if (article.cachedScore != null) return article.cachedScore!;
    
    final box = Hive.box<double>(interestsBoxName);
    final tags = article.tags;
    double score = 0.0;

    for (var tag in tags) {
      score += box.get(tag, defaultValue: 0.0) ?? 0.0;
    }
    article.cachedScore = score;
    return score;
  }
}
