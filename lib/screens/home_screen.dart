import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'article_detail_screen.dart';
import '../providers/news_provider.dart';
import '../providers/settings_provider.dart';
import '../models/news_category.dart';
import '../widgets/article_card.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  TabController? _tabController;
  List<NewsCategory> _activeCategories = [];

  @override
  void initState() {
    super.initState();
    _initTabs();
  }

  void _initTabs() {
    final settings = context.read<SettingsProvider>();
    _activeCategories = settings.activeCategories;
    
    _tabController?.dispose();
    if (_activeCategories.isNotEmpty) {
      _tabController = TabController(length: _activeCategories.length, vsync: this);
      
      // Jeśli wybrana kategoria w NewsProvider nie jest na liście aktywnych, ustawiamy pierwszą dostępną
      final newsProvider = context.read<NewsProvider>();
      if (!_activeCategories.any((c) => c.id == newsProvider.selectedCategory.id)) {
        newsProvider.setCategory(_activeCategories.first);
      }

      _tabController!.addListener(() {
        if (_tabController!.indexIsChanging) {
          context.read<NewsProvider>().setCategory(_activeCategories[_tabController!.index]);
        }
      });
    }

    // Pobieramy newsy na start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NewsProvider>().fetchNews(
        activeSourceIds: settings.activeSourceIds,
        favoriteTeams: settings.favoriteTeams,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sprawdzamy czy lista aktywnych kategorii się zmieniła
    final newActive = context.watch<SettingsProvider>().activeCategories;
    if (newActive.length != _activeCategories.length || 
        !newActive.every((c) => _activeCategories.contains(c))) {
      _initTabs();
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    
    if (_activeCategories.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('PRASÓWKA')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.category_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Wszystkie kategorie są wyłączone.'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  // Możemy tu dodać nawigację do ustawień lub przycisk powrotu
                },
                child: const Text('Przejdź do ustawień'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PRASÓWKA',
          style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900),
        ),
        bottom: _tabController != null ? TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppTheme.accentGold,
          labelColor: AppTheme.accentGold,
          unselectedLabelColor: Colors.white70,
          tabs: _activeCategories.map((cat) => Tab(text: cat.name.toUpperCase())).toList(),
        ) : null,
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
                    onPressed: () => provider.fetchNews(
                      activeSourceIds: settings.activeSourceIds,
                      favoriteTeams: settings.favoriteTeams,
                    ),
                    child: const Text('Spróbuj ponownie'),
                  ),
                ],
              ),
            );
          }

          if (provider.articles.isEmpty) {
            return const Center(child: Text('Brak artykułów.'));
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchNews(
              activeSourceIds: settings.activeSourceIds,
              favoriteTeams: settings.favoriteTeams,
            ),
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
