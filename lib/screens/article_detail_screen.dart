import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../theme/app_theme.dart';
import '../providers/news_provider.dart';

class ArticleDetailScreen extends StatelessWidget {
  final Article article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: article.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: article.imageUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(color: AppTheme.primaryNavy),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => Share.share('${article.title}\n\n${article.url}'),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_browser),
                onPressed: () => _launchUrl(article.url),
              ),
            ],
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        article.sourceName.toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.accentGold,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('dd.MM.yyyy HH:mm').format(article.publishedAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Text(
                    article.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  HtmlWidget(
                    article.content.isNotEmpty ? article.content : article.description,
                    textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 18,
                      height: 1.6,
                    ),
                    onTapUrl: (url) async {
                      await _launchUrl(url);
                      return true;
                    },
                  ),
                  
                  const SizedBox(height: 40),
                  
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: () => _launchUrl(article.url),
                      icon: const Icon(Icons.link),
                      label: const Text('CZYTAJ ORYGINAŁ W SERWISIE'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Consumer<NewsProvider>(
        builder: (context, provider, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                heroTag: 'readLater',
                onPressed: () => provider.toggleReadLater(article),
                backgroundColor: article.readLater ? AppTheme.accentGold : Colors.white,
                child: Icon(
                  article.readLater ? Icons.timer : Icons.timer_outlined,
                  color: article.readLater ? Colors.white : AppTheme.primaryNavy,
                ),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'favorite',
                onPressed: () => provider.toggleFavorite(article),
                backgroundColor: article.isFavorite ? Colors.red : Colors.white,
                child: Icon(
                  article.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: article.isFavorite ? Colors.white : Colors.red,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }
}
