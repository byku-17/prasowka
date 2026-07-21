import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/news_provider.dart';
import '../widgets/article_card.dart';
import 'article_detail_screen.dart';
import '../theme/app_theme.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewsProvider>();
    final favorites = provider.favoriteArticles;
    final readLater = provider.readLaterArticles;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ZAPISANE'),
          bottom: const TabBar(
            indicatorColor: AppTheme.accentGold,
            tabs: [
              Tab(text: 'ULUBIONE'),
              Tab(text: 'NA PÓŹNIEJ'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildList(context, favorites, 'Brak ulubionych artykułów'),
            _buildList(context, readLater, 'Brak artykułów na później'),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List articles, String emptyMsg) {
    if (articles.isEmpty) {
      return Center(child: Text(emptyMsg));
    }
    return ListView.builder(
      itemCount: articles.length,
      itemBuilder: (context, index) {
        final article = articles[index];
        return ArticleCard(
          article: article,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ArticleDetailScreen(article: article),
            ),
          ),
        );
      },
    );
  }
}
