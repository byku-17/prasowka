import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'article_detail_screen.dart';
import '../providers/news_provider.dart';
import '../models/news_category.dart';
import '../widgets/article_card.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<NewsCategory> _categories = NewsCategory.defaultCategories;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    
    // Pobieramy newsy na start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NewsProvider>().fetchNews();
    });

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        context.read<NewsProvider>().setCategory(_categories[_tabController.index]);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PRASÓWKA',
          style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.accentGold,
          labelColor: AppTheme.accentGold,
          unselectedLabelColor: Colors.white70,
          tabs: _categories.map((cat) => Tab(text: cat.name.toUpperCase())).toList(),
        ),
      ),
      body: Consumer<NewsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(provider.errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.fetchNews(),
                    child: const Text('Spróbuj ponownie'),
                  ),
                ],
              ),
            );
          }

          if (provider.articles.isEmpty) {
            return const Center(child: Text('Brak artykułów w tej kategorii.'));
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchNews(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: provider.articles.length,
              itemBuilder: (context, index) {
                final article = provider.articles[index];
                return ArticleCard(
                  article: article,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ArticleDetailScreen(article: article),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
