import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prasowka/screens/today_screen.dart';
import 'package:prasowka/screens/category_tab_screen.dart';
import 'package:prasowka/screens/topics_screen.dart';
import 'package:prasowka/screens/saved_screen.dart';
import 'package:prasowka/screens/search_bottom_sheet.dart';
import 'package:prasowka/screens/article_webview_screen.dart';
import 'package:prasowka/theme/app_theme.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/services/background_service.dart';
import 'package:prasowka/services/notification_history.dart';
import 'package:prasowka/services/auth_service.dart';
import 'package:prasowka/services/sync_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late int _currentIndex;
  late final PageController _pageController;
  DateTime? _lastBackPressTime;
  StreamSubscription? _notificationSubscription;
  final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);
  Timer? _autoRefreshTimer;
  bool _autoSyncInProgress = false;

  List<Widget> _screens = [];
  List<_TabDef> _tabs = [];
  String _lastCityName = '';

  @override
  void initState() {
    super.initState();
    _rebuildTabs();
    final settings = context.read<SettingsProvider>();
    _currentIndex = settings.lastTabIndex;
    if (_currentIndex >= _tabs.length) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);

    // Nasłuchiwanie powiadomień
    _notificationSubscription = BackgroundService().notificationStream.listen((url) {
      if (url != null) _handleNotificationUrl(url);
    });

    // Auto-odświeżanie treści
    settings.addListener(_onSettingsChanged);
    _scheduleAutoRefresh(settings.refreshFrequencyHours);

    // Automatyczna synchronizacja
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoSync());

    // Obsługa Cold Startu
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = BackgroundService().pendingPayload;
      if (pending != null) {
        BackgroundService().pendingPayload = null;
        _handleNotificationUrl(pending);
      }
    });
  }

  void _rebuildTabs() {
    final settings = context.read<SettingsProvider>();
    final slot1Cat = settings.getCategoryById(settings.mainTabSlot1);
    final slot2Cat = settings.getCategoryById(settings.mainTabSlot2);
    final slot1Label = settings.mainTabSlot1 == 'warsaw'
        ? settings.preferredCity
        : (slot1Cat?.name ?? 'Slot 1');
    final String slot2Label = slot2Cat?.name ?? 'Slot 2';
    _lastCityName = settings.preferredCity;

    _tabs = [
      _TabDef(label: 'Dzisiaj', icon: Icons.today, id: 'dzisiaj'),
      _TabDef(
        label: slot1Label,
        icon: slot1Cat?.icon ?? Icons.category,
        id: settings.mainTabSlot1,
      ),
      _TabDef(
        label: slot2Label,
        icon: slot2Cat?.icon ?? Icons.category,
        id: settings.mainTabSlot2,
      ),
      _TabDef(label: 'Tematy', icon: Icons.category, id: 'tematy'),
      _TabDef(label: 'Zapisane', icon: Icons.bookmark, id: 'zapisane'),
    ];

    _screens = [
      TodayScreen(refreshNotifier: refreshNotifier),
      CategoryTabScreen(categoryId: settings.mainTabSlot1, refreshNotifier: refreshNotifier),
      CategoryTabScreen(categoryId: settings.mainTabSlot2, refreshNotifier: refreshNotifier),
      const TopicsScreen(),
      const SavedScreen(),
    ];
  }

  void _onSettingsChanged() {
    _scheduleAutoRefresh(context.read<SettingsProvider>().refreshFrequencyHours);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _maybeAutoSync();
  }

  void _maybeAutoSync() {
    final settings = context.read<SettingsProvider>();
    if (!settings.autoSyncEnabled) return;
    if (!context.read<AuthService>().isLoggedIn) return;
    if (_autoSyncInProgress) return;
    _autoSyncInProgress = true;
    context.read<SyncService>().pushAll().whenComplete(() {
      _autoSyncInProgress = false;
    });
  }

  void _scheduleAutoRefresh(int hours) {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    if (hours <= 0) return;
    _autoRefreshTimer = Timer.periodic(Duration(hours: hours), (_) {
      refreshNotifier.value++;
    });
  }

  void _handleNotificationUrl(String url) {
    if (!mounted) return;
    NotificationHistory().markReadByUrl(url);
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
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
    WidgetsBinding.instance.removeObserver(this);
    context.read<SettingsProvider>().removeListener(_onSettingsChanged);
    _pageController.dispose();
    refreshNotifier.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) {
      refreshNotifier.value++;
      return;
    }
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
    // Only rebuild when the 3 tab-defining fields change (not on every settings change)
    final slotKey = context.select<SettingsProvider, ({String s1, String s2, String city})>(
      (s) => (s1: s.mainTabSlot1, s2: s.mainTabSlot2, city: s.preferredCity),
    );
    final newSlot1 = slotKey.s1;
    final newSlot2 = slotKey.s2;
    final newCity = slotKey.city;
    final slotsChanged = _tabs.length >= 3 && (_tabs[1].id != newSlot1 || _tabs[2].id != newSlot2);
    final cityChanged = newSlot1 == 'warsaw' && _lastCityName != newCity;
    if (slotsChanged || cityChanged) {
      _rebuildTabs();
      if (_currentIndex >= _tabs.length) _currentIndex = 0;
    }

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
              content: Text(
                'Naciśnij ponownie, aby wyjść z aplikacji',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.accentFor(context)),
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
          items: _tabs.map((tab) => BottomNavigationBarItem(
            icon: Icon(tab.icon),
            label: tab.label,
          )).toList(),
        ),
      ),
    );
  }
}

class _TabDef {
  final String label;
  final IconData icon;
  final String id;
  const _TabDef({required this.label, required this.icon, required this.id});
}
