import 'dart:async';
import 'package:flutter/material.dart';
import 'package:prasowka/services/rss_service.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/widgets/article_card.dart';
import 'package:prasowka/screens/article_detail_screen.dart';
import 'package:prasowka/theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => SearchScreenState();
}

class SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final RssService _rssService = RssService();
  Timer? _debounce;
  List<Article> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  bool _isSearchActive = false;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void activateSearch() {
    setState(() => _isSearchActive = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _deactivateSearch() {
    _searchController.clear();
    setState(() {
      _isSearchActive = false;
      _results = [];
      _hasSearched = false;
      _isLoading = false;
    });
    _focusNode.unfocus();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().length < 3) return;
    try {
      final results = await _rssService.searchGoogleNews(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSearchActive
          ? AppBar(
              title: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Szukaj w Google News...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _deactivateSearch,
              ),
              actions: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _results = [];
                        _hasSearched = false;
                        _isLoading = false;
                      });
                      _focusNode.requestFocus();
                    },
                  ),
              ],
            )
          : AppBar(title: const Text('SZUKAJ')),
      body: _isSearchActive ? _buildActiveBody() : _buildIdleBody(),
    );
  }

  Widget _buildIdleBody() {
    return Center(
      child: GestureDetector(
        onTap: activateSearch,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentGold.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppTheme.accentGold.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.search,
                size: 56,
                color: AppTheme.accentGold,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Kliknij, aby szukać',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Wyszukaj newsy w Google News',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.accentGold),
            SizedBox(height: 16),
            Text('Szukam w Google News...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 48, color: Colors.grey.shade700),
            const SizedBox(height: 16),
            Text(
              'Wpisz frazę (min. 3 znaki)',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Brak wyników', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.accentGold,
      onRefresh: () => _performSearch(_searchController.text),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final article = _results[index];
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
