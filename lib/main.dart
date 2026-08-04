import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/providers/sports_provider.dart';
import 'package:prasowka/screens/main_screen.dart';
import 'package:prasowka/screens/onboarding_screen.dart';
import 'package:prasowka/services/background_service.dart';
import 'package:prasowka/services/notification_history.dart';
import 'package:dynamic_color/dynamic_color.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  FlutterError.onError = (details) {
    debugPrint('Sowa Flutter Error: ${details.exception}');
    debugPrint(details.stack.toString());
  };

  await dotenv.load(fileName: ".env");
  await Hive.initFlutter();

  final settings = SettingsProvider();
  final news = NewsProvider();
  final sports = SportsProvider();

  try {
    await settings.init();
    await news.init();
    await NotificationHistory().init();
    await BackgroundService().init();

    // Sprawdzenie cold startu (aplikacja uruchomiona z powiadomienia)
    if (settings.notificationsEnabled) {
      await BackgroundService().registerPeriodicTask();
      await BackgroundService().checkNotificationLaunch();
    }
  } catch (e, stack) {
    debugPrint('Sowa Init Error: $e');
    debugPrint(stack.toString());
  }

  FlutterNativeSplash.remove();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: news),
        ChangeNotifierProvider.value(value: sports),
      ],
      child: const PrasowkaApp(),
    ),
  );
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
