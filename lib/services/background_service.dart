import 'dart:async';
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
import 'package:prasowka/services/notification_history.dart';
import 'package:prasowka/utils/text_utils.dart';
import 'package:flutter/foundation.dart';

const int _maxNotificationsPerRun = 5;
const String _sportsNotifiedBoxName = 'sports_notified_ids';
const String _pinnedMatchesBoxName = 'pinned_matches';
const String _pinnedScoresBoxName = 'pinned_match_scores';

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
      await NotificationHistory().init();

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
            final normalizedFavs = favoriteTeams.map((f) => TextUtils.normalize(f)).toList();
            final now = DateTime.now();

            for (var event in events) {
              if (event is! MatchEvent) continue;
              final searchable = TextUtils.normalize("${event.homeTeam} ${event.awayTeam} ${event.competition}");
              if (!normalizedFavs.any((f) => searchable.contains(f))) continue;

              bool shouldNotify = false;
              if (event.status == EventStatus.live) {
                shouldNotify = true;
              } else if (event.status == EventStatus.scheduled) {
                // Sprawdź czy to na pewno dzisiaj (zapobiega alertom o tej samej godzinie jutro)
                final isToday = event.date.year == now.year &&
                               event.date.month == now.month &&
                               event.date.day == now.day;
                               
                if (isToday) {
                  // Porównuj czas (godzina:minuta)
                  final eventMinutes = event.date.hour * 60 + event.date.minute;
                  final nowMinutes = now.hour * 60 + now.minute;
                  final diffMinutes = eventMinutes - nowMinutes;
                  if (diffMinutes >= 0 && diffMinutes <= 15) shouldNotify = true;
                }
              }
              if (!shouldNotify) continue;

              final notifiedKey = '${event.id}_${event.date.year}_${event.date.month}_${event.date.day}';
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

      // --- POWIADOMIENIA LIVE SCORE (PRZYPINANIE) ---
      try {
        if (!Hive.isBoxOpen(_pinnedMatchesBoxName)) {
          await Hive.openBox(_pinnedMatchesBoxName);
        }
        final pinnedBox = Hive.box(_pinnedMatchesBoxName);
        final pinnedIds = pinnedBox.keys.map((k) => k.toString()).toList();

        if (pinnedIds.isNotEmpty) {
          if (!Hive.isBoxOpen(_pinnedScoresBoxName)) {
            await Hive.openBox(_pinnedScoresBoxName);
          }
          final scoresBox = Hive.box(_pinnedScoresBoxName);
          final sportsService = SportsService();
          final events = await sportsService.fetchAllEvents();

          for (var event in events) {
            if (event is! MatchEvent) continue;
            if (!pinnedIds.contains(event.id)) continue;
            if (event.status != EventStatus.live) continue;

            final prevScore = scoresBox.get(event.id, defaultValue: '') as String;
            final currentScore = event.score;

            if (prevScore.isNotEmpty && prevScore != currentScore) {
              // Wynik się zmienił → powiadomienie o golu
              await _showGoalNotification(event, prevScore, currentScore);
              notifiedCount++;
            }

            // Zapisz aktualny wynik
            await scoresBox.put(event.id, currentScore);

            if (notifiedCount >= _maxNotificationsPerRun) break;
          }
        }
      } catch (e) {
        debugPrint('Sowa Wartownik: Błąd powiadomień pinned: $e');
      }

      // --- PRZYPOMNIENIA ME CZOWE (5 min przed startem) ---
      try {
        const remindersBoxName = 'match_reminders_notified';
        if (!Hive.isBoxOpen(remindersBoxName)) {
          await Hive.openBox(remindersBoxName);
        }
        final remindersBox = Hive.box(remindersBoxName);

        if (!Hive.isBoxOpen(_pinnedMatchesBoxName)) {
          await Hive.openBox(_pinnedMatchesBoxName);
        }
        final pinnedBox = Hive.box(_pinnedMatchesBoxName);
        final pinnedIds = pinnedBox.keys.map((k) => k.toString()).toSet();

        if (pinnedIds.isNotEmpty) {
          final sportsService = SportsService();
          final events = await sportsService.fetchAllEvents();
          final now = DateTime.now();

          for (var event in events) {
            if (event is! MatchEvent) continue;
            if (!pinnedIds.contains(event.id)) continue;
            if (event.status != EventStatus.scheduled) continue;

            final eventTime = event.date;
            
            // Sprawdź czy to na pewno dzisiaj (zapobiega reminderom o tej samej godzinie jutro)
            final isToday = eventTime.year == now.year &&
                           eventTime.month == now.month &&
                           eventTime.day == now.day;
                           
            if (!isToday) continue;

            final diffMinutes = eventTime.difference(now).inMinutes;

            // Wyślij przypomnienie 5 minut przed meczem (w oknie 3-7 min)
            if (diffMinutes >= 3 && diffMinutes <= 7) {
              final reminderKey = '${event.id}_reminder_${event.date.day}_${event.date.month}';
              if (remindersBox.get(reminderKey, defaultValue: false) == true) continue;

              await _showMatchReminder(event);
              await remindersBox.put(reminderKey, true);
              notifiedCount++;
              if (notifiedCount >= _maxNotificationsPerRun) break;
            }
          }
        }
      } catch (e) {
        debugPrint('Sowa Wartownik: Błąd przypomnień meczowych: $e');
      }

      debugPrint('Sowa Wartownik: Zakończono. Wysłano $notifiedCount powiadomień');
      return Future.value(true);
    } catch (e) {
      debugPrint('Sowa Wartownik: Krytyczny błąd callbackDispatcher: $e');
      return Future.value(false);
    }
  });
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
    id: article.id.hashCode.abs(),
    title: 'Sowa znalazła coś dla Ciebie! 🦉',
    body: article.title,
    notificationDetails: platformChannelSpecifics,
    payload: article.url,
  );

  await NotificationHistory().add(NotificationEntry(
    id: article.id,
    title: 'Sowa znalazła coś dla Ciebie! 🦉',
    body: article.title,
    url: article.url,
    timestamp: DateTime.now(),
    type: 'article',
  ));
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
    id: event.id.hashCode.abs(),
    title: title,
    body: body,
    notificationDetails: platformChannelSpecifics,
  );

  await NotificationHistory().add(NotificationEntry(
    id: 'sport_${event.id}',
    title: title,
    body: body,
    timestamp: DateTime.now(),
    type: 'sport',
  ));
}

Future<void> _showGoalNotification(MatchEvent event, String prevScore, String newScore) async {
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

  final title = '⚽ GOL! — ${event.competition}';
  final body = '${event.homeTeam} $newScore ${event.awayTeam}';

  await flutterLocalNotificationsPlugin.show(
    id: event.id.hashCode.abs() + DateTime.now().millisecondsSinceEpoch % 1000,
    title: title,
    body: body,
    notificationDetails: platformChannelSpecifics,
  );

  await NotificationHistory().add(NotificationEntry(
    id: 'sport_goal_${event.id}_${DateTime.now().millisecondsSinceEpoch}',
    title: title,
    body: body,
    timestamp: DateTime.now(),
    type: 'sport',
  ));
}

Future<void> _showMatchReminder(MatchEvent event) async {
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

  final title = '⏰ Za chwilę! — ${event.competition}';
  final body = '${event.homeTeam} vs ${event.awayTeam} zaczyna się za kilka minut!';

  // Buduj URL Flashscore dla konkretnego meczu (fallback na główną stronę)
  final flashscoreUrl = _buildFlashscoreMatchUrl(event);

  await flutterLocalNotificationsPlugin.show(
    id: event.id.hashCode.abs() + 7777,
    title: title,
    body: body,
    notificationDetails: platformChannelSpecifics,
    payload: flashscoreUrl,
  );

  await NotificationHistory().add(NotificationEntry(
    id: 'sport_reminder_${event.id}',
    title: title,
    body: body,
    url: flashscoreUrl,
    timestamp: DateTime.now(),
    type: 'sport',
  ));
}

String _buildFlashscoreMatchUrl(MatchEvent event) {
  // Flashscore nie ma bezpośrednich URL-i do meczów bez ID,
  // ale main page zawsze pokazuje nadchodzące mecze
  return 'https://www.flashscore.com';
}

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  /// Strumień do przesyłania payloadu (URL) z powiadomień do UI
  final _notificationStreamController = StreamController<String?>.broadcast();
  Stream<String?> get notificationStream => _notificationStreamController.stream;

  /// URL z powiadomienia, z którego użytkownik uruchomił aplikację (cold start)
  String? pendingPayload;

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _notifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          debugPrint('Sowa Notyfikacje: Kliknięto powiadomienie, payload: $payload');
          _notificationStreamController.add(payload);
        }
      },
    );

    // Android 13+ wymaga runtime permission dla powiadomień
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

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
        _notificationStreamController.add(payload);
      }
    }
  }

  Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      "sowa-wartownik-task",
      "checkNewArticlesTask",
      frequency: const Duration(hours: 1),
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
    id: 999,
    title: 'Test Wartownika 🦉',
    body: 'Powiadomienia działają poprawnie. Sowa czuwa!',
    notificationDetails: platformChannelSpecifics,
  );

    await NotificationHistory().add(NotificationEntry(
      id: 'test_999',
      title: 'Test Wartownika 🦉',
      body: 'Powiadomienia działają poprawnie. Sowa czuwa!',
      timestamp: DateTime.now(),
      type: 'article',
    ));
  }
}
