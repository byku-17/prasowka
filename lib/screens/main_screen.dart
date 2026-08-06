import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/screens/today_screen.dart';
import 'package:prasowka/screens/city_screen.dart';
import 'package:prasowka/screens/sport_screen.dart';
import 'package:prasowka/screens/saved_screen.dart';
import 'package:prasowka/screens/topics_screen.dart';
import 'package:prasowka/screens/search_bottom_sheet.dart';
import 'package:prasowka/screens/article_webview_screen.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/services/background_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  late final PageController _pageController;
  DateTime? _lastBackPressTime;
  StreamSubscription? _notificationSubscription;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = context.read<SettingsProvider>().lastTabIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _screens = [
      const TodayScreen(),
      const CityScreen(),
      const SportScreen(),
      const SavedScreen(),
      const TopicsScreen(),
    ];

    // Nasłuchiwanie powiadomień
    _notificationSubscription = BackgroundService().notificationStream.listen((url) {
      if (url != null) _handleNotificationUrl(url);
    });

    // Obsługa Cold Startu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = BackgroundService().pendingPayload;
      if (pending != null) {
        BackgroundService().pendingPayload = null;
        _handleNotificationUrl(pending);
      }
    });
  }

  void _handleNotificationUrl(String url) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleWebViewScreen(
          url: url,
          title: 'Sowa poleca...',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    context.read<SettingsProvider>().setLastTabIndex(index);
  }

  void _openSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SearchBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_currentIndex != 0) {
          _onTabTapped(0);
          return;
        }

        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Naciśnij ponownie, aby wyjść z aplikacji',
                textAlign: TextAlign.center,
              ),
              backgroundColor: AppTheme.primaryNavy,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(50, 0, 50, 30),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
          return;
        }

        await SystemNavigator.pop();
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          physics: const ClampingScrollPhysics(),
          children: _screens,
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _openSearch,
          backgroundColor: AppTheme.accentFor(context),
          foregroundColor: Colors.white,
          elevation: 6,
          shape: const CircleBorder(),
          child: const Icon(Icons.search, size: 28),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.accentFor(context),
          unselectedItemColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey
              : AppTheme.graphite,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.today), label: 'Dzisiaj'),
            BottomNavigationBarItem(icon: Icon(Icons.location_city), label: 'Miasto'),
            BottomNavigationBarItem(icon: Icon(Icons.sports_soccer), label: 'Sport'),
            BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Zapisane'),
            BottomNavigationBarItem(icon: Icon(Icons.category), label: 'Tematy'),
          ],
        ),
      ),
    );
  }
}
