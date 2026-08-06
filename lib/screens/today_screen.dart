import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/widgets/article_card.dart';
import 'package:prasowka/screens/article_detail_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchNews());
  }

  void _fetchNews() {
    final settings = context.read<SettingsProvider>();
    final provider = context.read<NewsProvider>();
    final allSources = settings.allSources;
    final enabledIds = settings.enabledSourceIds;
    provider.fetchNews(
      allSources: allSources,
      enabledSourceIds: enabledIds,
      keywords: settings.keywords,
      forceRefresh: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewsProvider>();
    final articles = provider.articles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TWOJE NOWINY'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: articles.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => _fetchNews(),
              child: ListView.builder(
                itemCount: articles.length,
                itemBuilder: (context, index) {
                  final article = articles[index];
                  return ArticleCard(
                    article: article,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ArticleDetailScreen(article: article),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
