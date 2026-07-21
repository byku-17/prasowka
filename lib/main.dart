import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'theme/app_theme.dart';
import 'providers/news_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicjalizacja Hive
  await Hive.initFlutter();
  
  // Tworzymy providery i inicjalizujemy je przed startem aplikacji
  final settingsProvider = SettingsProvider();
  await settingsProvider.init();
  
  final newsProvider = NewsProvider();
  await newsProvider.init();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: newsProvider),
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
    
    return MaterialApp(
      title: 'Prasówka',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode, // Teraz motyw zależy od ustawień
      home: const SplashScreen(),
    );
  }
}
