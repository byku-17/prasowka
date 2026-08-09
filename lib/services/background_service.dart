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
const int _maxNotificationsPerDay = 20;
const String _sportsNotifiedBoxName = 'sports_notified_ids';
const String _pinnedMatchesBoxName = 'pinned_matches';
const String _pinnedScoresBoxName = 'pinned_match_scores';
const String _dailyCountBoxName = 'daily_notification_count';

const String _groupSport = 'sowa_sport_group';
const String _groupArticle = 'sowa_article_group';

/// Dzienny licznik powiadomień — klucz: data (yyyy-MM-dd)
String _todayKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// Czy obecna godzina mieści się w oknie działania powiadomień.
bool _isWithinNotificationWindow() {
  if (!Hive.isBoxOpen('settings')) return true;
  final box = Hive.box('settings');
  final start = (box.get('notificationStartHour', defaultValue: 7) as num).toInt();
  final end = (box.get('notificationEndHour', defaultValue: 21) as num).toInt();
  final hour = DateTime.now().hour;
  if (start <= end) return hour >= start && hour < end;
  // Okno przechodzące przez północ (np. 22:00–06:00)
  return hour >= start || hour < end;
}

Future<int> _getDailyCount() async {
  if (!Hive.isBoxOpen(_dailyCountBoxName)) {
    await Hive.openBox(_dailyCountBoxName);
  }
  final box = Hive.box(_dailyCountBoxName);
  return (box.get(_todayKey(), defaultValue: 0) as int);
}

Future<void> _incrementDailyCount() async {
  if (!Hive.isBoxOpen(_dailyCountBoxName)) {
    await Hive.openBox(_dailyCountBoxName);
  }
  final box = Hive.box(_dailyCountBoxName);
  final key = _todayKey();
  final current = (box.get(key, defaultValue: 0) as int);
  await box.put(key, current + 1);
}

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

      final dailyCount = await _getDailyCount();
      if (dailyCount >= _maxNotificationsPerDay) {
        debugPrint('Sowa Wartownik: Dzienny limit $_maxNotificationsPerDay osiągnięty ($dailyCount)');
        return Future.value(true);
      }

      if (!Hive.isBoxOpen('settings')) {
        await Hive.openBox('settings');
      }
      if (!_isWithinNotificationWindow()) {
        debugPrint('Sowa Wartownik: Poza godzinami działania — pomijam cykl');
        return Future.value(true);
      }

      notifiedCount += await _handleRssNotifications(storage, interest, rss, notifiedCount);

      List<SportEvent> sportEvents = [];
      try {
        if (Hive.isBoxOpen('settings')) {
          sportEvents = await SportsService().fetchAllEvents();
        }
      } catch (e) {
        debugPrint('Sowa Wartownik: Błąd pobierania danych sportowych: $e');
      }

      notifiedCount += await _handleFavoriteNotifications(sportEvents, notifiedCount);
      notifiedCount += await _handlePinnedScoreNotifications(sportEvents, notifiedCount);
      notifiedCount += await _handleMatchReminders(sportEvents, notifiedCount);

      debugPrint('Sowa Wartownik: Zakończono. Wysłano $notifiedCount powiadomień');
      return Future.value(true);
    } catch (e) {
      debugPrint('Sowa Wartownik: Krytyczny błąd callbackDispatcher: $e');
      return Future.value(false);
    }
  });
}

Future<int> _handleRssNotifications(StorageService storage, UserInterestService interest, RssService rss, int startCount) async {
  int count = 0;
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
            count++;
            if (startCount + count >= _maxNotificationsPerRun) return count;
          }
        }
      }
    } catch (e) {
      debugPrint('Sowa Wartownik: Błąd pobierania źródła ${source.name}: $e');
    }
  }
  return count;
}

Future<int> _handleFavoriteNotifications(List<SportEvent> sportEvents, int startCount) async {
  int count = 0;
  try {
    if (!Hive.isBoxOpen('settings')) return 0;
    final settingsBox = Hive.box('settings');
    final resultEnabled = settingsBox.get('sportResultNotifications', defaultValue: true) as bool;
    final startEnabled = settingsBox.get('sportStartNotifications', defaultValue: true) as bool;
    final favoriteTeams = List<String>.from(settingsBox.get('favoriteTeams', defaultValue: <String>[]));
    if (favoriteTeams.isEmpty || sportEvents.isEmpty) return 0;

    if (!Hive.isBoxOpen(_sportsNotifiedBoxName)) {
      await Hive.openBox(_sportsNotifiedBoxName);
    }
    final sportsBox = Hive.box(_sportsNotifiedBoxName);
    final normalizedFavs = favoriteTeams.map((f) => TextUtils.normalize(f)).toList();
    final now = DateTime.now();

    for (var event in sportEvents) {
      if (event is! MatchEvent) continue;
      final searchable = TextUtils.normalize("${event.homeTeam} ${event.awayTeam} ${event.competition}");
      if (!normalizedFavs.any((f) => searchable.contains(f))) continue;

      bool shouldNotify = false;
      if (event.status == EventStatus.live) {
        shouldNotify = resultEnabled;
      } else if (event.status == EventStatus.scheduled && startEnabled) {
        final isToday = event.date.year == now.year && event.date.month == now.month && event.date.day == now.day;
        if (isToday) {
          final diffMinutes = (event.date.hour * 60 + event.date.minute) - (now.hour * 60 + now.minute);
          if (diffMinutes >= 0 && diffMinutes <= 15) shouldNotify = true;
        }
      }
      if (!shouldNotify) continue;

      final notifiedKey = '${event.id}_${event.date.year}_${event.date.month}_${event.date.day}';
      if (sportsBox.get(notifiedKey, defaultValue: false) == true) continue;

      await _showSportNotification(event);
      await sportsBox.put(notifiedKey, true);
      count++;
      if (startCount + count >= _maxNotificationsPerRun) break;
    }
  } catch (e) {
    debugPrint('Sowa Wartownik: Błąd powiadomień sportowych: $e');
  }
  return count;
}

Future<int> _handlePinnedScoreNotifications(List<SportEvent> sportEvents, int startCount) async {
  int count = 0;
  try {
    if (!Hive.isBoxOpen(_pinnedMatchesBoxName)) {
      await Hive.openBox(_pinnedMatchesBoxName);
    }
    final pinnedBox = Hive.box(_pinnedMatchesBoxName);
    final pinnedIds = pinnedBox.keys.map((k) => k.toString()).toList();
    if (pinnedIds.isEmpty || sportEvents.isEmpty) return 0;

    if (!Hive.isBoxOpen('settings')) return 0;
    final resultEnabled = Hive.box('settings').get('sportResultNotifications', defaultValue: true) as bool;
    if (!resultEnabled) return 0;

    if (!Hive.isBoxOpen(_pinnedScoresBoxName)) {
      await Hive.openBox(_pinnedScoresBoxName);
    }
    final scoresBox = Hive.box(_pinnedScoresBoxName);

    for (var event in sportEvents) {
      if (event is! MatchEvent) continue;
      if (!pinnedIds.contains(event.id)) continue;
      if (event.status != EventStatus.live) continue;

      final prevScore = scoresBox.get(event.id, defaultValue: '') as String;
      final currentScore = event.score;

      if (prevScore.isNotEmpty && prevScore != currentScore) {
        await _showGoalNotification(event, prevScore, currentScore);
        count++;
      }

      await scoresBox.put(event.id, currentScore);
      if (startCount + count >= _maxNotificationsPerRun) break;
    }
  } catch (e) {
    debugPrint('Sowa Wartownik: Błąd powiadomień pinned: $e');
  }
  return count;
}

Future<int> _handleMatchReminders(List<SportEvent> sportEvents, int startCount) async {
  int count = 0;
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
    if (pinnedIds.isEmpty || sportEvents.isEmpty) return 0;

    if (!Hive.isBoxOpen('settings')) return 0;
    final startEnabled = Hive.box('settings').get('sportStartNotifications', defaultValue: true) as bool;
    if (!startEnabled) return 0;

    final now = DateTime.now();

    for (var event in sportEvents) {
      if (event is! MatchEvent) continue;
      if (!pinnedIds.contains(event.id)) continue;
      if (event.status != EventStatus.scheduled) continue;

      final isToday = event.date.year == now.year && event.date.month == now.month && event.date.day == now.day;
      if (!isToday) continue;

      final diffMinutes = event.date.difference(now).inMinutes;
      if (diffMinutes >= 3 && diffMinutes <= 7) {
        final reminderKey = '${event.id}_reminder_${event.date.day}_${event.date.month}';
        if (remindersBox.get(reminderKey, defaultValue: false) == true) continue;

        await _showMatchReminder(event);
        await remindersBox.put(reminderKey, true);
        count++;
        if (startCount + count >= _maxNotificationsPerRun) break;
      }
    }
  } catch (e) {
    debugPrint('Sowa Wartownik: Błąd przypomnień meczowych: $e');
  }
  return count;
}

Future<void> _showNotification(Article article) async {
  final dailyCount = await _getDailyCount();
  if (dailyCount >= _maxNotificationsPerDay) return;

  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'sowa_alerts',
    'Wartownik Sowy',
    channelDescription: 'Powiadomienia o ważnych dla Ciebie tematach',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    groupKey: _groupArticle,
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
  await _incrementDailyCount();
}

Future<void> _showSportNotification(MatchEvent event) async {
  final dailyCount = await _getDailyCount();
  if (dailyCount >= _maxNotificationsPerDay) return;

  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'sowa_sport',
    'Sowa Sport',
    channelDescription: 'Powiadomienia o meczach Twoich drużyn',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    groupKey: _groupSport,
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
  await _incrementDailyCount();
}

Future<void> _showGoalNotification(MatchEvent event, String prevScore, String newScore) async {
  final dailyCount = await _getDailyCount();
  if (dailyCount >= _maxNotificationsPerDay) return;

  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'sowa_sport',
    'Sowa Sport',
    channelDescription: 'Powiadomienia o meczach Twoich drużyn',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    groupKey: _groupSport,
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
  await _incrementDailyCount();
}

Future<void> _showMatchReminder(MatchEvent event) async {
  final dailyCount = await _getDailyCount();
  if (dailyCount >= _maxNotificationsPerDay) return;

  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'sowa_sport',
    'Sowa Sport',
    channelDescription: 'Powiadomienia o meczach Twoich drużyn',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    groupKey: _groupSport,
  );

  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final title = '⏰ Za chwilę! — ${event.competition}';
  final body = '${event.homeTeam} vs ${event.awayTeam} zaczyna się za kilka minut!';

  await flutterLocalNotificationsPlugin.show(
    id: event.id.hashCode.abs() + 7777,
    title: title,
    body: body,
    notificationDetails: platformChannelSpecifics,
    payload: 'https://www.flashscore.com',
  );

  await NotificationHistory().add(NotificationEntry(
    id: 'sport_reminder_${event.id}',
    title: title,
    body: body,
    url: 'https://www.flashscore.com',
    timestamp: DateTime.now(),
    type: 'sport',
  ));
  await _incrementDailyCount();
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

  Future<void> registerPeriodicTask({int frequencyHours = 1}) async {
    await Workmanager().cancelAll();
    await Workmanager().registerPeriodicTask(
      "sowa-wartownik-task",
      "checkNewArticlesTask",
      frequency: Duration(hours: frequencyHours),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
  }

  Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
  }
}
