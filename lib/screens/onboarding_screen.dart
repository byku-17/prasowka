import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:prasowka/providers/settings_provider.dart';
import 'package:prasowka/models/news_category.dart';
import 'package:prasowka/theme/app_theme.dart';

import 'package:prasowka/screens/main_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Kroki onboardingu
  final List<String> _selectedCategories = [];
  final List<String> _favoriteKeywords = [];
  final TextEditingController _keywordController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() async {
    final settings = context.read<SettingsProvider>();
    
    // 1. Zapisujemy wybrane kategorie
    if (_selectedCategories.isNotEmpty) {
      await settings.setSelectedCategories(_selectedCategories);
    }

    // 2. Dodajemy słowa kluczowe (firmy, drużyny)
    for (var kw in _favoriteKeywords) {
      await settings.addKeyword(kw);
    }

    // 3. Markujemy onboarding jako zakończony i wchodzimy do aplikacji
    await settings.completeOnboarding();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2126),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildWelcomePage(),
                  _buildInterestsPage(),
                  _buildKeywordsPage(),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/logo.webp', height: 120),
          const SizedBox(height: 40),
          Text(
            'WITAJ W PRASÓWCE',
            textAlign: TextAlign.center,
            style: GoogleFonts.syne(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.accentGold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Twoja osobista sowa informacyjna. Pomogę Ci przesiać internet i znaleźć to, co dla Ciebie najważniejsze.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text(
            'CO CIĘ INTERESUJE?',
            style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.accentGold),
          ),
          const SizedBox(height: 12),
          const Text('Wybierz tematy, które sowa ma śledzić w pierwszej kolejności:', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: NewsCategory.defaultCategories.where((c) => c.id != 'all').length,
              itemBuilder: (context, index) {
                final cat = NewsCategory.defaultCategories.where((c) => c.id != 'all').toList()[index];
                final isSelected = _selectedCategories.contains(cat.id);
                return InkWell(
                  onTap: () {
                    setState(() {
                      isSelected ? _selectedCategories.remove(cat.id) : _selectedCategories.add(cat.id);
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.accentGold : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? AppTheme.accentGold : Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(cat.icon, color: isSelected ? Colors.black : Colors.white70, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          cat.name.toUpperCase(),
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeywordsPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text(
            'PERSONALIZACJA',
            style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.accentGold),
          ),
          const SizedBox(height: 12),
          const Text('Wpisz firmy, drużyny sportowe lub tematy (np. Tesla, Iga Świątek, Bitcoin). Sowa będzie je promować na Twojej liście.', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 24),
          TextField(
            controller: _keywordController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Dodaj słowo kluczowe...',
              hintStyle: const TextStyle(color: Colors.white24),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add_circle, color: AppTheme.accentGold),
                onPressed: () {
                  if (_keywordController.text.trim().isNotEmpty) {
                    setState(() {
                      _favoriteKeywords.add(_keywordController.text.trim());
                      _keywordController.clear();
                    });
                  }
                },
              ),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accentGold)),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _favoriteKeywords.map((kw) => Chip(
              label: Text(kw),
              onDeleted: () => setState(() => _favoriteKeywords.remove(kw)),
              backgroundColor: AppTheme.accentGold.withValues(alpha: 0.1),
              side: const BorderSide(color: AppTheme.accentGold),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Kropki postępu
          Row(
            children: List.generate(3, (index) => Container(
              margin: const EdgeInsets.only(right: 8),
              width: index == _currentPage ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: index == _currentPage ? AppTheme.accentGold : Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            )),
          ),
          // Przycisk Dalej/Start
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: Text(
              _currentPage == 2 ? 'ZACZNIJMY!' : 'DALEJ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
