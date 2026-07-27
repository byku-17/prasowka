import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/screens/home_screen.dart';
import 'package:prasowka/screens/search_screen.dart';
import 'package:prasowka/screens/saved_screen.dart';
import 'package:prasowka/screens/settings_screen.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/settings_provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  late final PageController _pageController;
  DateTime? _lastBackPressTime;

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    SavedScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = context.read<SettingsProvider>().lastTabIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
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
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.accentGold,
          unselectedItemColor: Colors.grey,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Główna'),
            BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Szukaj'),
            BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Zapisane'),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ustawienia'),
          ],
        ),
      ),
    );
  }
}
