import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/providers/tag_provider.dart';
import 'package:prasowka/theme/app_theme.dart';

class TagPickerBottomSheet extends StatelessWidget {
  final Article article;
  const TagPickerBottomSheet({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final tags = context.watch<TagProvider>().tags;
    final accent = AppTheme.accentFor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2126) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.label, color: accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Otaguj artykuł',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            if (tags.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Brak tagów — utwórz w ustawieniach',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: tags.map((tag) {
                    final isSelected = article.tagIds.contains(tag.id);
                    return ListTile(
                      leading: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: tag.color.withValues(alpha: isSelected ? 0.25 : 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(tag.icon, color: tag.color, size: 18),
                      ),
                      title: Text(
                        tag.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? tag.color : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: tag.color, size: 22)
                          : Icon(Icons.circle_outlined, color: Colors.grey.shade400, size: 22),
                      onTap: () {
                        context.read<NewsProvider>().toggleArticleTag(article, tag.id);
                      },
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
