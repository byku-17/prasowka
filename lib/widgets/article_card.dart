import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/news_provider.dart';

class ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;
  final bool isSmall;

  const ArticleCard({
    super.key,
    required this.article,
    required this.onTap,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: isSmall ? 4 : 16, 
        vertical: isSmall ? 4 : 8
      ),
      clipBehavior: Clip.antiAlias,
      // Optymalizacja: usunięcie zbędnych cieni przy szybkim przewijaniu na małych kartach
      elevation: isSmall ? 0 : 2,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: isSmall ? 280 : double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (article.imageUrl != null)
                AspectRatio(
                  aspectRatio: isSmall ? 1.8 : 16 / 9, // Zmieniono 2.8 na 1.8 dla lepszych proporcji
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: article.imageUrl!,
                          fit: BoxFit.cover, // To gwarantuje brak rozciągania (tylko przycinanie)
                          memCacheHeight: isSmall ? 250 : 500,
                          memCacheWidth: isSmall ? 450 : 900,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.withValues(alpha: 0.1),
                          ),
                          errorWidget: (context, url, error) => const SizedBox.shrink(),
                        ),
                        _buildTranslationWatermark(),
                      ],
                    ),
                  ),
                ),
              
              Padding(
                padding: EdgeInsets.all(isSmall ? 8.0 : 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nagłówek (tytuł)
                    Selector<NewsProvider, String>(
                      selector: (_, p) => article.translatedTitle ?? article.title,
                      builder: (context, title, child) => Text(
                        title,
                        style: (isSmall 
                          ? Theme.of(context).textTheme.titleSmall 
                          : Theme.of(context).textTheme.titleLarge)?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    if (!isSmall) ...[
                      const SizedBox(height: 6),
                      Selector<NewsProvider, String>(
                        selector: (_, p) => article.translatedDescription ?? article.description,
                        builder: (context, desc, child) => Text(
                          desc,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            article.sourceName,
                            style: const TextStyle(color: AppTheme.accentGold, fontWeight: FontWeight.bold, fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTimeAgo(article.publishedAt),
                          style: const TextStyle(color: Colors.grey, fontSize: 9),
                        ),
                        if (!isSmall) ...[
                          const SizedBox(width: 12),
                          _buildActions(context),
                        ],
                      ],
                    ),
                    if (isSmall) ...[
                      const SizedBox(height: 6),
                      _buildActions(context),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTranslationWatermark() {
    return Selector<NewsProvider, bool>(
      selector: (_, provider) => !provider.isArticlePolish(article) && article.translatedTitle == null,
      builder: (context, needsTranslation, child) {
        if (!needsTranslation) return const SizedBox.shrink();
        return Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.translate, size: 12, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: isSmall ? MainAxisAlignment.spaceAround : MainAxisAlignment.end,
      children: [
        _ReactionButton(
          iconBuilder: (isActive) => isActive ? Icons.thumb_up : Icons.thumb_up_outlined,
          colorBuilder: (isActive) => isActive ? AppTheme.accentGold : Colors.grey,
          selector: (p) => article.isLiked,
          onPressed: () => context.read<NewsProvider>().toggleLike(article),
        ),
        _ReactionButton(
          iconBuilder: (isActive) => isActive ? Icons.thumb_down : Icons.thumb_down_outlined,
          colorBuilder: (isActive) => isActive ? Colors.red : Colors.grey,
          selector: (p) => article.isDisliked,
          onPressed: () => context.read<NewsProvider>().toggleDislike(article),
        ),
        _ReactionButton(
          iconBuilder: (isActive) => isActive ? Icons.favorite : Icons.favorite_border,
          colorBuilder: (isActive) => isActive ? Colors.red : Colors.grey,
          selector: (p) => article.isFavorite,
          onPressed: () => context.read<NewsProvider>().toggleFavorite(article),
        ),
        _ReactionButton(
          iconBuilder: (isActive) => isActive ? Icons.timer : Icons.timer_outlined,
          colorBuilder: (isActive) => isActive ? AppTheme.accentGold : Colors.grey,
          selector: (p) => article.readLater,
          onPressed: () => context.read<NewsProvider>().toggleReadLater(article),
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays > 0) return '${difference.inDays}d temu';
    if (difference.inHours > 0) return '${difference.inHours}h temu';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m temu';
    return 'teraz';
  }
}

class _ReactionButton extends StatelessWidget {
  final IconData Function(bool) iconBuilder;
  final Color Function(bool) colorBuilder;
  final bool Function(NewsProvider) selector;
  final VoidCallback onPressed;

  const _ReactionButton({
    required this.iconBuilder,
    required this.colorBuilder,
    required this.selector,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<NewsProvider, bool>(
      selector: (_, p) => selector(p),
      builder: (context, isActive, child) {
        // GestureDetector jest lżejszy niż InkWell/IconButton
        return GestureDetector(
          onTap: onPressed,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Icon(
              iconBuilder(isActive),
              color: colorBuilder(isActive),
              size: 14,
            ),
          ),
        );
      },
    );
  }
}
