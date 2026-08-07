import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/services/notification_history.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/screens/article_detail_screen.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final history = NotificationHistory();
    final entries = history.all;

    return Scaffold(
      appBar: AppBar(
        title: const Text('POWIADOMIENIA'),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Wyczyść historię',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Wyczyścić historię?'),
                    content: const Text('Wszystkie powiadomienia zostaną usunięte.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('ANULUJ')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('WYCZYŚĆ',
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await history.clear();
                  setState(() {});
                }
              },
            ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  Text('Brak powiadomień',
                      style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    'Sowa poinformuje Cię o ważnych tematach',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _buildTile(context, entry);
              },
            ),
    );
  }

  Widget _buildTile(BuildContext context, NotificationEntry entry) {
    final isSport = entry.type == 'sport';
    final timeStr = _formatTime(entry.timestamp);
    final icon = isSport ? Icons.sports_soccer : Icons.article_outlined;
    final iconColor = isSport ? Colors.green : AppTheme.accentFor(context);

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.7,
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) async {
        await NotificationHistory().delete(entry.id);
        setState(() {});
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.15),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          entry.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight:
                entry.isRead ? FontWeight.normal : FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '$timeStr · ${entry.title.replaceAll('🦉', '').trim()}',
            style: TextStyle(color: Colors.grey[500], fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: entry.url != null
            ? Icon(Icons.chevron_right, color: Colors.grey[600], size: 20)
            : null,
        onTap: entry.url != null ? () => _openArticle(context, entry) : null,
        onLongPress: () async {
          final history = NotificationHistory();
          if (entry.isRead) {
            await history.markUnread(entry.id);
          } else {
            await history.markRead(entry.id);
          }
          setState(() {});
        },
      ),
    );
  }

  @override
  void dispose() {
    NotificationHistory().markAllRead();
    super.dispose();
  }

  void _openArticle(BuildContext context, NotificationEntry entry) {
    if (entry.url == null) return;

    final provider = context.read<NewsProvider>();
    final cachedArticle = provider.allLoadedArticles
        .where((a) => a.url == entry.url)
        .toList();

    if (cachedArticle.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ArticleDetailScreen(article: cachedArticle.first),
        ),
      );
    } else {
      launchUrl(Uri.parse(entry.url!),
          mode: LaunchMode.externalApplication);
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Teraz';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min temu';
    if (diff.inHours < 24) return '${diff.inHours}h temu';
    if (diff.inDays < 7) return '${diff.inDays} dni temu';
    return DateFormat('dd.MM HH:mm').format(dt);
  }
}
