import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prasowka/models/article.dart';
import 'package:prasowka/models/news_source.dart';
import 'package:prasowka/services/rss_service.dart';
import 'package:prasowka/services/storage_service.dart';
import 'package:prasowka/services/user_interest_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await Hive.initFlutter();
      
      final storage = StorageService();
      final interest = UserInterestService();
      final rss = RssService();
      
      await storage.init();
      await interest.init();

      final sources = NewsSource.defaultSources.where((s) => NewsSource.topSourceIds.contains(s.id)).toList();

      for (var source in sources) {
        final articles = await rss.fetchArticles(source);
        for (var article in articles) {
          // Sprawdzamy czy nie wysyłaliśmy już powiadomienia o tym newsie
          if (!storage.wasNotified(article.id)) {
            final score = interest.calculateScore(article);
            
            if (score >= 3.0) {
              await _showNotification(article);
              await storage.markAsNotified(article.id);
              return Future.value(true);
            }
          }
        }
      }
      return Future.value(true);
    } catch (e) {
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
    article.id.hashCode,
    'Sowa znalazła coś dla Ciebie! 🦉',
    article.title,
    platformChannelSpecifics,
    payload: article.url,
  );
}

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    
    await _notifications.initialize(initializationSettings);

    await Workmanager().initialize(
      callbackDispatcher,
    );
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
