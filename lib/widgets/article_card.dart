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
    if (isSmall) {
      return _buildSmallCard(context);
    }

    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Zdjęcie na pełną szerokość (Edge-to-Edge)
          if (article.imageUrl != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: article.imageUrl!,
                    fit: BoxFit.cover, // Wypełnia przestrzeń wycinając nadmiar, nie rozciąga
                    alignment: Alignment.center,
                    // Ustawiamy tylko szerokość cache, wysokość dostosuje się z zachowaniem proporcji
                    memCacheWidth: 1080, 
                    placeholder: (context, url) => Container(
                      color: Colors.grey.withValues(alpha: 0.1),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.withValues(alpha: 0.05),
                      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                    ),
                  ),
                  _buildTranslationWatermark(),
                ],
              ),
            ),
          
          // Treść z marginesami
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Selector<NewsProvider, String>(
                  selector: (_, p) => article.translatedTitle ?? article.title,
                  builder: (context, title, child) => Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 19,
                      height: 1.25,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Selector<NewsProvider, String>(
                  selector: (_, p) => article.translatedDescription ?? article.description,
                  builder: (context, desc, child) => Text(
                    desc,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white70 
                          : Colors.black87,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        article.sourceName.toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.accentGold, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimeAgo(article.publishedAt),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    const SizedBox(width: 16),
                    _buildActions(context),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _buildSmallCard(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(left: 16, right: 4, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.imageUrl != null)
                AspectRatio(
                  aspectRatio: 1.8,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: article.imageUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 600, // Tylko szerokość dla zachowania proporcji
                        errorWidget: (context, url, error) => const SizedBox.shrink(),
                      ),
                      _buildTranslationWatermark(),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.translatedTitle ?? article.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            article.sourceName,
                            style: const TextStyle(color: AppTheme.accentGold, fontSize: 10, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildActions(context),
                      ],
                    ),
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('EN', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
          iconBuilder: (isActive) => isActive ? Icons.bookmark : Icons.bookmark_border,
          colorBuilder: (isActive) => isActive ? Colors.blue : Colors.grey,
          selector: (p) => article.readLater,
          onPressed: () => context.read<NewsProvider>().toggleReadLater(article),
        ),
        _ReactionButton(
          iconBuilder: (isActive) => isActive ? Icons.favorite : Icons.favorite_border,
          colorBuilder: (isActive) => isActive ? Colors.red : Colors.grey,
          selector: (p) => article.isFavorite,
          onPressed: () => context.read<NewsProvider>().toggleFavorite(article),
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays > 0) return '${difference.inDays}d';
    if (difference.inHours > 0) return '${difference.inHours}h';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m';
    return 'teraz';
  }
}

class _ReactionButton extends StatefulWidget {
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
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton> {
  bool _isPressed = false;

  void _handleTap() {
    setState(() => _isPressed = true);
    widget.onPressed();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _isPressed = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Selector<NewsProvider, bool>(
      selector: (_, p) => widget.selector(p),
      builder: (context, isActive, child) {
        return GestureDetector(
          onTap: _handleTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: AnimatedScale(
              scale: _isPressed ? 1.3 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOut,
              child: Icon(
                widget.iconBuilder(isActive),
                color: widget.colorBuilder(isActive),
                size: 20,
                shadows: isActive ? [
                  Shadow(
                    color: widget.colorBuilder(isActive).withValues(alpha: 0.3),
                    blurRadius: 8,
                  )
                ] : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
