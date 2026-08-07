import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/providers/sports_provider.dart';
import 'package:prasowka/providers/tag_provider.dart';
import 'package:prasowka/screens/main_screen.dart';
import 'package:prasowka/screens/onboarding_screen.dart';
import 'package:prasowka/services/background_service.dart';
import 'package:prasowka/services/notification_history.dart';
import 'package:prasowka/services/reading_history.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:prasowka/services/remote_config_service.dart';
import 'package:prasowka/services/auth_service.dart';
import 'package:prasowka/services/sync_service.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Firebase.initializeApp();

  // Crashlytycs — łapanie błędów Flutter
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  runZonedGuarded(() async {
    await dotenv.load(fileName: ".env");
    await RemoteConfigService().init();
    await Hive.initFlutter();

    final settings = SettingsProvider();
    final news = NewsProvider();
    final sports = SportsProvider();
    final tags = TagProvider();
    final auth = AuthService();
    final sync = SyncService(auth);

    try {
      await settings.init();
      await news.init();
      await tags.init();
      await NotificationHistory().init();
      await ReadingHistory().init();
      await BackgroundService().init();
      await sports.loadCacheFromHive();

      if (settings.notificationsEnabled) {
        await BackgroundService().registerPeriodicTask();
        await BackgroundService().checkNotificationLaunch();
      }

      if (auth.isLoggedIn) {
        sync.setEncryptionPassword(auth.user?.uid ?? '');
        sync.mergeFirstLogin();
      }
    } catch (e, stack) {
      debugPrint('Sowa Init Error: $e');
      await FirebaseCrashlytics.instance.recordError(e, stack, reason: 'Init failed');
    }

    FlutterNativeSplash.remove();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: news),
          ChangeNotifierProvider.value(value: sports),
          ChangeNotifierProvider.value(value: tags),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: sync),
        ],
        child: const PrasowkaApp(),
      ),
    );
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
}

class PrasowkaApp extends StatelessWidget {
  const PrasowkaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp(
          title: 'Prasówka',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.getTheme(settings.themeVariant, false, dynamicScheme: lightDynamic),
          darkTheme: AppTheme.getTheme(settings.themeVariant, true, dynamicScheme: darkDynamic),
          themeMode: settings.themeMode,
          home: settings.onboardingCompleted ? const MainScreen() : const OnboardingScreen(),
        );
      },
    );
  }
}
