import 'package:hive/hive.dart';

part 'article.g.dart';

@HiveType(typeId: 0)
class Article extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String content;

  @HiveField(4)
  final String url;

  @HiveField(5)
  final String? imageUrl;

  @HiveField(6)
  final DateTime publishedAt;

  @HiveField(7)
  final String sourceName;

  @HiveField(8)
  bool isFavorite;

  @HiveField(9)
  bool readLater;

  Article({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.url,
    required this.publishedAt,
    required this.sourceName,
    this.imageUrl,
    this.isFavorite = false,
    this.readLater = false,
  });

  /// Oblicza przybliżony czas czytania (zakładając średnio 200 słów na minutę)
  int get estimatedReadingTime {
    final words = (content.isNotEmpty ? content : description).split(' ').length;
    final minutes = (words / 200).ceil();
    return minutes > 0 ? minutes : 1;
  }
}
