import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prasowka/providers/news_provider.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/models/news_category.dart';
import 'package:prasowka/widgets/category_news_list.dart';
import 'package:prasowka/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  TabController? _tabController;
  List<NewsCategory> _activeCategories = [];

  @override
  void initState() {
    super.initState();
    _initTabs();
  }

  void _initTabs() {
    final settings = context.read<SettingsProvider>();
    final newActive = settings.activeCategories;
    
    bool hasChanged = _activeCategories.length != newActive.length;
    if (!hasChanged) {
      for (int i = 0; i < _activeCategories.length; i++) {
        if (_activeCategories[i].id != newActive[i].id) {
          hasChanged = true;
          break;
        }
      }
    }

    if (!hasChanged && _tabController != null) return;

    _activeCategories = List.from(newActive);
    _tabController?.dispose();
    
    if (_activeCategories.isNotEmpty) {
      _tabController = TabController(length: _activeCategories.length, vsync: this);
      _tabController!.addListener(() {
        if (!_tabController!.indexIsChanging) {
          context.read<NewsProvider>().setCategory(_activeCategories[_tabController!.index]);
        }
      });
    }
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initTabs();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_activeCategories.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('PRASÓWKA')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.category_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Wszystkie kategorie są wyłączone.'),
              SizedBox(height: 8),
              Text('Zmień to w ustawieniach!', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'PRASÓWKA',
          style: GoogleFonts.syne(
            letterSpacing: 2.0, 
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Column(
            children: [
              if (_tabController != null)
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  indicatorColor: AppTheme.accentGold,
                  labelColor: AppTheme.accentGold,
                  unselectedLabelColor: Colors.white70,
                  tabs: _activeCategories.map((cat) => Tab(text: cat.name.toUpperCase())).toList(),
                ),
              const SizedBox(height: 2),
            ],
          ),
        ),
      ),
      body: _tabController != null 
        ? TabBarView(
            controller: _tabController,
            children: _activeCategories.map((cat) => CategoryNewsList(category: cat)).toList(),
          )
        : const Center(child: CircularProgressIndicator()),
    );
  }
}
