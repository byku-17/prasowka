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

  @HiveField(10)
  String? fullContent;

  @HiveField(11)
  bool isLiked;

  @HiveField(12)
  bool isDisliked;

  @HiveField(13)
  String? translatedTitle;

  @HiveField(14)
  String? translatedDescription;

  @HiveField(15)
  String? translatedFullContent;

  @HiveField(16)
  int readTimeSeconds;

  @HiveField(17)
  bool isRead;

  // Pola pomocnicze (niezapisywane w Hive)
  List<String>? _cachedTags;
  double? cachedScore;

  List<String> get tags {
    if (_cachedTags != null) return _cachedTags!;
    final text = '$title $description'.toLowerCase();
    final stopWords = {
      'i', 'w', 'na', 'z', 'do', 'o', 'za', 'oraz', 'ze', 'po', 'przy', 'dla', 'nie', 'tak', 'co', 'jak', 'że', 'się', 'the', 'a', 'an', 'of', 'in', 'to', 'for', 'with'
    };
    _cachedTags = text.split(RegExp(r'[^a-ząćęłńóśźż]+'))
        .where((w) => w.length > 3 && !stopWords.contains(w))
        .toSet()
        .toList();
    return _cachedTags!;
  }

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
    this.fullContent,
    this.isLiked = false,
    this.isDisliked = false,
    this.translatedTitle,
    this.translatedDescription,
    this.translatedFullContent,
    this.readTimeSeconds = 0,
    this.isRead = false,
  });

  /// Oblicza przybliżony czas czytania (zakładając średnio 200 słów na minutę)
  int get estimatedReadingTime {
    final words = (content.isNotEmpty ? content : description).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final minutes = (words / 200).ceil();
    return minutes > 0 ? minutes : 1;
  }

  /// Konwersja do Map (bezpieczna dla isolate boundaries)
  Map<String, dynamic> toTransferMap() => {
    'id': id,
    'title': title,
    'description': description,
    'content': content,
    'url': url,
    'imageUrl': imageUrl,
    'publishedAt': publishedAt.millisecondsSinceEpoch,
    'sourceName': sourceName,
    'isFavorite': isFavorite,
    'readLater': readLater,
    'fullContent': fullContent,
    'isLiked': isLiked,
    'isDisliked': isDisliked,
    'translatedTitle': translatedTitle,
    'translatedDescription': translatedDescription,
    'translatedFullContent': translatedFullContent,
    'readTimeSeconds': readTimeSeconds,
    'isRead': isRead,
  };

  /// Odtworzenie z Map (bezpieczna dla isolate boundaries)
  factory Article.fromTransferMap(Map<String, dynamic> m) => Article(
    id: m['id'] ?? '',
    title: m['title'] ?? '',
    description: m['description'] ?? '',
    content: m['content'] ?? '',
    url: m['url'] ?? '',
    imageUrl: m['imageUrl'],
    publishedAt: DateTime.fromMillisecondsSinceEpoch(m['publishedAt'] ?? 0),
    sourceName: m['sourceName'] ?? '',
    isFavorite: m['isFavorite'] ?? false,
    readLater: m['readLater'] ?? false,
    fullContent: m['fullContent'],
    isLiked: m['isLiked'] ?? false,
    isDisliked: m['isDisliked'] ?? false,
    translatedTitle: m['translatedTitle'],
    translatedDescription: m['translatedDescription'],
    translatedFullContent: m['translatedFullContent'],
    readTimeSeconds: m['readTimeSeconds'] ?? 0,
    isRead: m['isRead'] ?? false,
  );
}
