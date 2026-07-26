import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/models/news_source.dart';
import 'package:prasowka/models/sport_event.dart';
import 'package:prasowka/services/rss_service.dart';
import 'package:prasowka/services/storage_service.dart';
import 'package:prasowka/services/sports_service.dart';
import 'package:prasowka/services/user_interest_service.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

const int _maxNotificationsPerRun = 5;
const String _sportsNotifiedBoxName = 'sports_notified_ids';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    int notifiedCount = 0;
    try {
      await Hive.initFlutter();
      
      final storage = StorageService();
      final interest = UserInterestService();
      final rss = RssService();
      
      await storage.init();
      await interest.init();

      // --- POWIADOMIENIA RSS ---
      final sources = NewsSource.defaultSources.where((s) => NewsSource.topSourceIds.contains(s.id)).toList();

      for (var source in sources) {
        try {
          final articles = await rss.fetchArticles(source);
          for (var article in articles) {
            if (!storage.wasNotified(article.id)) {
              final score = interest.calculateScore(article);
              
              if (score >= 3.0) {
                await _showNotification(article);
                await storage.markAsNotified(article.id);
                notifiedCount++;
                if (notifiedCount >= _maxNotificationsPerRun) {
                  debugPrint('Sowa Wartownik: Osiągnięto limit $_maxNotificationsPerRun powiadomień na run');
                  return Future.value(true);
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Sowa Wartownik: Błąd pobierania źródła ${source.name}: $e');
        }
      }

      // --- POWIADOMIENIA SPORTOWE ---
      try {
        const settingsBoxName = 'settings';
        if (Hive.isBoxOpen(settingsBoxName)) {
          final settingsBox = Hive.box(settingsBoxName);
          final favoriteTeams = List<String>.from(settingsBox.get('favoriteTeams', defaultValue: <String>[]));

          if (favoriteTeams.isNotEmpty) {
            if (!Hive.isBoxOpen(_sportsNotifiedBoxName)) {
              await Hive.openBox(_sportsNotifiedBoxName);
            }
            final sportsBox = Hive.box(_sportsNotifiedBoxName);
            final sportsService = SportsService();
            final events = await sportsService.fetchAllEvents();
            final normalizedFavs = favoriteTeams.map((f) => _normalize(f)).toList();
            final now = DateTime.now();

            for (var event in events) {
              if (event is! MatchEvent) continue;
              final searchable = _normalize("${event.homeTeam} ${event.awayTeam} ${event.competition}");
              if (!normalizedFavs.any((f) => searchable.contains(f))) continue;

              bool shouldNotify = false;
              if (event.status == EventStatus.live) {
                shouldNotify = true;
              } else if (event.status == EventStatus.scheduled) {
                final diff = now.difference(event.date).inMinutes;
                if (diff >= 0 && diff <= 15) shouldNotify = true;
              }
              if (!shouldNotify) continue;

              final notifiedKey = '${event.id}_${now.year}_${now.month}_${now.day}';
              if (sportsBox.get(notifiedKey, defaultValue: false) == true) continue;

              await _showSportNotification(event);
              await sportsBox.put(notifiedKey, true);
              notifiedCount++;
              if (notifiedCount >= _maxNotificationsPerRun) break;
            }
          }
        }
      } catch (e) {
        debugPrint('Sowa Wartownik: Błąd powiadomień sportowych: $e');
      }

      debugPrint('Sowa Wartownik: Zakończono. Wysłano $notifiedCount powiadomień');
      return Future.value(true);
    } catch (e) {
      debugPrint('Sowa Wartownik: Krytyczny błąd callbackDispatcher: $e');
      return Future.value(false);
    }
  });
}

String _normalize(String text) {
  var str = text.toLowerCase();
  const polish = 'ąćęłńóśźż';
  const latin = 'acelnoszz';
  for (int i = 0; i < polish.length; i++) {
    str = str.replaceAll(polish[i], latin[i]);
  }
  str = str.replaceAll('fc ', '').replaceAll(' ks ', '').replaceAll(' gks ', '').replaceAll(' pko bp ', '');
  return str.trim();
}

Future<void> _showNotification(Article article) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'sowa_alerts',
    'Wartownik Sowy',
    channelDescription: 'Powiadomienia o ważnych dla Ciebie tematach',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );
  
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);
      
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin.show(
    article.id.hashCode,
    'Sowa znalazła coś dla Ciebie! 🦉',
    article.title,
    platformChannelSpecifics,
    payload: article.url,
  );
}

Future<void> _showSportNotification(MatchEvent event) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'sowa_sport',
    'Sowa Sport',
    channelDescription: 'Powiadomienia o meczach Twoich drużyn',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  String title;
  String body;
  if (event.status == EventStatus.live) {
    title = '🔴 LIVE — ${event.competition}';
    body = '${event.homeTeam} ${event.score} ${event.awayTeam}';
  } else {
    title = '⚽ Mecz się rozpoczął! — ${event.competition}';
    body = '${event.homeTeam} vs ${event.awayTeam}';
  }

  await flutterLocalNotificationsPlugin.show(
    event.id.hashCode,
    title,
    body,
    platformChannelSpecifics,
  );
}

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  /// URL z powiadomienia, z którego użytkownik uruchomił aplikację (cold start)
  static String? pendingPayload;

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          debugPrint('Sowa Notyfikacje: Kliknięto powiadomienie, payload: $payload');
          pendingPayload = payload;
          _openUrl(payload);
        }
      },
    );

    await Workmanager().initialize(
      callbackDispatcher,
    );
  }

  /// Sprawdza czy aplikacja została uruchomiona z powiadomienia (cold start)
  Future<void> checkNotificationLaunch() async {
    final details = await _notifications.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp) {
      final payload = details.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        debugPrint('Sowa Notyfikacje: Cold start z powiadomienia, payload: $payload');
        pendingPayload = payload;
        _openUrl(payload);
      }
    }
  }

  /// Otwiera URL w przeglądarce
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      "sowa-wartownik-task",
      "checkNewArticlesTask",
      frequency: const Duration(hours: 3),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
  }

  Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
  }

  Future<void> showTestNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'sowa_test',
      'Test Sowy',
      channelDescription: 'Kanał do testowania powiadomień',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notifications.show(
      999,
      'Test Wartownika 🦉',
      'Powiadomienia działają poprawnie. Sowa czuwa!',
      platformChannelSpecifics,
    );
  }
}
