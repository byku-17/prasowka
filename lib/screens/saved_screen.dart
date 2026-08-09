import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/models/user_tag.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/providers/tag_provider.dart';
import 'package:prasowka/screens/article_detail_screen.dart';
import 'package:prasowka/screens/settings_screen.dart';
import 'package:prasowka/services/reading_history.dart';
import 'package:prasowka/services/image_cache_manager.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/widgets/article_card.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  String? _selectedTagId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Article> _filterArticles(List<Article> articles) {
    var filtered = articles;
    if (_selectedTagId != null) {
      filtered = filtered.where((a) => a.tagIds.contains(_selectedTagId)).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((a) =>
        a.title.toLowerCase().contains(q) ||
        a.description.toLowerCase().contains(q) ||
        a.sourceName.toLowerCase().contains(q)
      ).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final allSaved = context.select<NewsProvider, List<Article>>((p) => p.savedArticles);
    final tags = context.watch<TagProvider>().tags;
    final filtered = _filterArticles(allSaved);

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
              icon: Icon(_showSearch ? Icons.close : Icons.search, color: Colors.grey.shade600),
              onPressed: () => setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  _searchQuery = '';
                }
              }),
            ),
            IconButton(
              icon: Icon(Icons.settings, color: Colors.grey.shade600),
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
              Tab(text: 'ZAPISANE'),
              Tab(text: 'HISTORIA'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSavedTab(context, filtered, tags, allSaved),
            const _HistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedTab(BuildContext context, List<Article> filtered, List<UserTag> tags, List<Article> allSaved) {
    return Column(
      children: [
        if (_showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Szukaj w zapisanych...',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 20),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        if (tags.isNotEmpty && allSaved.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _buildTagChip(context, null, 'Wszystkie', AppTheme.accentFor(context)),
                const SizedBox(width: 6),
                ...tags.map((tag) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _buildTagChip(context, tag.id, tag.name, tag.color),
                )),
              ],
            ),
          ),
        Expanded(
          child: _buildArticleList(context, filtered),
        ),
      ],
    );
  }

  Widget _buildTagChip(BuildContext context, String? tagId, String label, Color color) {
    final isSelected = _selectedTagId == tagId;
    return GestureDetector(
      onTap: () => setState(() => _selectedTagId = isSelected ? null : tagId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? color : color.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildArticleList(BuildContext context, List<Article> items) {
    if (items.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Brak wyników'
                  : _selectedTagId != null
                      ? 'Brak artykułów z tym tagiem'
                      : 'Brak zapisanych artykułów',
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
                builder: (context) => ArticleDetailScreen(
                  article: article,
                  articles: items,
                  currentIndex: index,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  List<HistoryEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    final history = ReadingHistory().getAll();
    setState(() {
      _entries = history;
      _isLoading = false;
    });
  }

  void _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wyczyść historię?'),
        content: const Text('Ta operacja jest nieodwracalna.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Wyczyść', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ReadingHistory().clear();
      _loadHistory();
    }
  }

  void _openArticle(HistoryEntry entry) {
    final article = Article(
      id: entry.id,
      title: entry.title,
      description: entry.description ?? '',
      content: '',
      url: entry.url,
      imageUrl: entry.imageUrl,
      sourceName: entry.sourceName,
      publishedAt: entry.publishedAt,
      isSaved: false,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
    ).then((_) => _loadHistory());
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'przed chwilą';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min temu';
    if (diff.inHours < 24) return '${diff.inHours} godz temu';
    if (diff.inDays < 7) return '${diff.inDays} dni temu';
    return DateFormat('dd.MM.yyyy HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_entries.isEmpty) return _buildEmptyState();
    return _buildList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Brak historii',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Artykuły, które otworzysz,\npojawią się tutaj',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final grouped = <String, List<HistoryEntry>>{};
    for (final entry in _entries) {
      final dayKey = DateFormat('yyyy-MM-dd').format(entry.openedAt);
      grouped.putIfAbsent(dayKey, () => []).add(entry);
    }
    final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        if (_entries.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.delete_sweep, size: 20),
              onPressed: _clearHistory,
              tooltip: 'Wyczyść historię',
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: days.length,
            itemBuilder: (context, dayIndex) {
              final day = days[dayIndex];
              final dayEntries = grouped[day]!;
              final dayDate = DateTime.parse(day);
              final isToday = DateTime.now().difference(dayDate).inDays == 0;
              final isYesterday = DateTime.now().difference(dayDate).inDays == 1;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      isToday ? 'Dzisiaj' : isYesterday ? 'Wczoraj' : DateFormat('d MMMM yyyy', 'pl_PL').format(dayDate),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentFor(context),
                      ),
                    ),
                  ),
                  ...dayEntries.map((entry) => _buildEntry(entry)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEntry(HistoryEntry entry) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => _openArticle(entry),
        child: Row(
          children: [
            if (context.read<SettingsProvider>().showImagesNow && entry.imageUrl != null && entry.imageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: entry.imageUrl!,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                cacheManager: AppImageCacheManager.instance,
                errorWidget: (_, __, ___) => Container(
                  width: 64,
                  height: 64,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              )
            else
              Container(
                width: 64,
                height: 64,
                color: Colors.grey.shade300,
                child: const Icon(Icons.article, color: Colors.grey),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.language, size: 11, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            entry.sourceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ),
                        Text(
                          _formatTime(entry.openedAt),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
