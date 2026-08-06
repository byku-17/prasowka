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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedText = isDark ? Colors.white.withValues(alpha: 0.5) : Colors.grey;
    final checkIconColor = isDark ? Colors.white.withValues(alpha: 0.3) : Colors.grey;
    final dividerColor = isDark ? Colors.white24 : Colors.grey.shade300;
    final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200;

    if (isSmall) {
      return _buildSmallCard(context, mutedText, checkIconColor, cardBorderColor);
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
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      article.isRead ? Colors.black.withValues(alpha: 0.4) : Colors.transparent,
                      BlendMode.darken,
                    ),
                    child: CachedNetworkImage(
                      imageUrl: article.imageUrl!,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
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
                Consumer<NewsProvider>(
                  builder: (context, _, child) {
                    final isRead = article.isRead;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            article.translatedTitle ?? article.title,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                              height: 1.25,
                              color: isRead ? mutedText : null,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isRead) ...[
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Icon(Icons.check_circle, color: checkIconColor, size: 16),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Consumer<NewsProvider>(
                  builder: (context, _, child) => Opacity(
                    opacity: article.isRead ? 0.6 : 1.0,
                    child: Text(
                      article.translatedDescription ?? article.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontSize: 14,
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Opacity(
                  opacity: article.isRead ? 0.5 : 1.0,
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (article.sourceName.contains('Warszawa') || article.sourceName.startsWith('Wiadomości:'))
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(Icons.location_on, color: AppTheme.accentFor(context), size: 12),
                              ),
                            Flexible(
                              child: Text(
                                article.sourceName.toUpperCase(),
                                style: TextStyle(
                                  color: AppTheme.accentFor(context), 
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimeAgo(article.publishedAt),
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      const SizedBox(width: 16),
                      _buildActions(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: dividerColor),
        ],
      ),
    );
  }

  Widget _buildSmallCard(BuildContext context, Color mutedText, Color checkIconColor, Color borderColor) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(left: 16, right: 4, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
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
                        memCacheWidth: 600,
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
                        color: article.isRead ? mutedText : null,
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
                            style: TextStyle(color: AppTheme.accentFor(context), fontSize: 10, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (article.isRead)
                          Icon(Icons.check_circle, color: checkIconColor, size: 14),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildActionsSmall(context),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Row(
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
      ),
    );
  }

  Widget _buildActionsSmall(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ReactionButton(
          iconBuilder: (isActive) => isActive ? Icons.thumb_up : Icons.thumb_up_outlined,
          colorBuilder: (isActive) => isActive ? AppTheme.accentGold : Colors.grey,
          selector: (p) => article.isLiked,
          onPressed: () => context.read<NewsProvider>().toggleLike(article),
          small: true,
        ),
        _ReactionButton(
          iconBuilder: (isActive) => isActive ? Icons.favorite : Icons.favorite_border,
          colorBuilder: (isActive) => isActive ? Colors.red : Colors.grey,
          selector: (p) => article.isFavorite,
          onPressed: () => context.read<NewsProvider>().toggleFavorite(article),
          small: true,
        ),
        _ReactionButton(
          iconBuilder: (isActive) => isActive ? Icons.bookmark : Icons.bookmark_border,
          colorBuilder: (isActive) => isActive ? Colors.blue : Colors.grey,
          selector: (p) => article.readLater,
          onPressed: () => context.read<NewsProvider>().toggleReadLater(article),
          small: true,
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
  final bool small;

  const _ReactionButton({
    required this.iconBuilder,
    required this.colorBuilder,
    required this.selector,
    required this.onPressed,
    this.small = false,
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
            padding: EdgeInsets.symmetric(
              horizontal: widget.small ? 4 : 8,
              vertical: widget.small ? 2 : 6,
            ),
            child: AnimatedScale(
              scale: _isPressed ? 1.3 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOut,
              child: Icon(
                widget.iconBuilder(isActive),
                color: widget.colorBuilder(isActive),
                size: widget.small ? 16 : 22,
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
