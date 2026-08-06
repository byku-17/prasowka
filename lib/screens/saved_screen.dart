import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/screens/article_detail_screen.dart';
import 'package:prasowka/screens/settings_screen.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/widgets/article_card.dart';

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
          title: const Text(
            'ZAPISANE',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppTheme.accentFor(context),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
            tabs: const [
              Tab(text: 'ULUBIONE'),
              Tab(text: 'NA PÓŹNIEJ'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildArticleList(context, favorites, 'Brak ulubionych artykułów', Icons.favorite_border),
            _buildArticleList(context, readLater, 'Brak artykułów na później', Icons.bookmark_border),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleList(BuildContext context, List<Article> items, String emptyMsg, IconData emptyIcon) {
    if (items.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              emptyMsg,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppTheme.accentGold,
      onRefresh: () async {},
      child: ListView.builder(
        padding: EdgeInsets.zero,
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
      ),
    );
  }
}
