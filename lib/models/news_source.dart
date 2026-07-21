/// Reprezentuje źródło informacji (np. kanał RSS konkretnego portalu).
class NewsSource {
  final String id;
  final String name;
  final String rssUrl;
  final String? logoUrl;
  final String categoryId;

  const NewsSource({
    required this.id,
    required this.name,
    required this.rssUrl,
    required this.categoryId,
    this.logoUrl,
  });

  /// Przykładowe źródła na start
  static List<NewsSource> get defaultSources => [
    const NewsSource(
      id: 'rmf24_polska',
      name: 'RMF24',
      rssUrl: 'https://www.rmf24.pl/fakty/polska/feed',
      categoryId: 'poland',
    ),
    const NewsSource(
      id: 'bbc_world',
      name: 'BBC News',
      rssUrl: 'http://feeds.bbci.co.uk/news/world/rss.xml',
      categoryId: 'world',
    ),
    const NewsSource(
      id: 'money_pl',
      name: 'Money.pl',
      rssUrl: 'https://www.money.pl/rss/main.xml',
      categoryId: 'business',
    ),
  ];
}
