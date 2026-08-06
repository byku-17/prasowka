import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/widgets/article_card.dart';
import 'package:prasowka/screens/article_detail_screen.dart';
import 'package:prasowka/theme/app_theme.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewsProvider>();
    final List<Article> favorites = provider.favoriteArticles;
    final List<Article> readLater = provider.readLaterArticles;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ZAPISANE'),
          bottom: TabBar(
            indicatorColor: AppTheme.accentFor(context),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
            tabs: [
              Tab(text: 'ULUBIONE'),
              Tab(text: 'NA PÓŹNIEJ'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildArticleList(context, favorites, 'Brak ulubionych artykułów'),
            _buildArticleList(context, readLater, 'Brak artykułów na później'),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleList(BuildContext context, List<Article> items, String emptyMsg) {
    if (items.isEmpty) {
      return Center(child: Text(emptyMsg));
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final article = items[index];
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
