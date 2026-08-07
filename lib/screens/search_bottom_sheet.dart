import 'dart:async';
import 'package:flutter/material.dart';
import 'package:prasowka/services/rss_service.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/widgets/article_card.dart';
import 'package:prasowka/screens/article_detail_screen.dart';
import 'package:prasowka/theme/app_theme.dart';

class SearchBottomSheet extends StatefulWidget {
  const SearchBottomSheet({super.key});

  @override
  State<SearchBottomSheet> createState() => _SearchBottomSheetState();
}

class _SearchBottomSheetState extends State<SearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final RssService _rssService = RssService();
  Timer? _debounce;
  List<Article> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  static const _popularTopics = [
    'Polska',
    'Świat',
    'Polityka',
    'Gospodarka',
    'Klimat',
    'AI',
    'Piłka nożna',
    'Ekstraklasa',
    'Premier League',
    'NBA',
    'Sport',
    'Kultura',
    'Nauka',
    'Technologia',
    'Podróże',
  ];

  @override
  void initState() {
    super.initState();
    // Autofocus - od razu pokazuj klawiaturę
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
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

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _results = [];
      _hasSearched = false;
      _isLoading = false;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              autofocus: true,
              style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.graphite),
              decoration: InputDecoration(
                hintText: 'Szukaj w Google News...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: AppTheme.accentFor(context)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: _clearSearch,
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          // Results
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.accentFor(context)),
            const SizedBox(height: 16),
            const Text('Szukam w Google News...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'POPULARNE TEMATY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _popularTopics.map((topic) {
              return GestureDetector(
                onTap: () {
                  _searchController.text = topic;
                  _onSearchChanged(topic);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white12
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Text(
                    topic,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : AppTheme.graphite,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
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
      color: AppTheme.accentFor(context),
      onRefresh: () => _performSearch(_searchController.text),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 100),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final article = _results[index];
          return ArticleCard(
            article: article,
            onTap: () {
              Navigator.pop(context); // zamknij bottom sheet
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArticleDetailScreen(
                    article: article,
                    articles: _results,
                    currentIndex: index,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}