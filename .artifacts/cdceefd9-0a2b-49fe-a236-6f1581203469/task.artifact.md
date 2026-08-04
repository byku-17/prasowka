# Zadania: Rozwój V5.0 — V7.11

## Zrealizowane

- [x] **KROK 1: Stabilizacja i Cleanup** (ZREALIZOWANO V5.1)
- [x] **KROK 2: In-App WebView (Premium UX)** (ZREALIZOWANO V5.2)
- [x] **KROK 3: Szlifowanie "Mojego Miasta" (V5.3.1)** (ZREALIZOWANO)
- [x] **KROK 4: Inteligentna Gazeta (V5.4)** (ZREALIZOWANO)
- [x] **5.1 Integracja Powiadomień z WebView** (ZREALIZOWANO V5.5)
- [x] **5.2 Ujednolicenie Kategorii Miejskiej** (ZREALIZOWANO V6.1)
- [x] **5.3 Poprawa Logiki Wartownika (Sport)** (ZREALIZOWANO V6.2)
- [x] **V7.0: Personalizacja kolorystyki** — Classic, Elegant Light, Royal Purple, Dynamic Color
- [x] **V7.10: Ostateczne rozwiązanie JVM Target** — cleanup importów, przebudowa build.gradle.kts
- [x] **V7.11: Upgrade pluginów do Built-in Kotlin** — flutter_local_notifications 22.x, workmanager 0.10.7, share_plus 13.3.0, desugar_jdk_libs 2.1.4, Java 21, fix named params w show/initialize

## Nowe w V7.11

- [x] **Rozjaśnienie Royal Purple** — #905CFF → #B47AFF (jaśniejszy, pastelowy), nowe kolory: royalPurpleDark #8B5CF6, lightPurple #E8DAFF, royalDarkBg #1A1528
- [x] **Ujednolicenie ustawień motywu** — usunięto duplikaty (Tryb jasny/ciemny + Kolorystyka), jedno menu z 4 opcjami: Jasny / Medium (fioletowy) / Ciemny / Systemowy
- [x] **Usunięto Medium Slate theme** (nieaktualne po ujednoliceniu)

## Do realizacji (V7.12 — V8.0): "Mniej klików, więcej treści"

### Faza 1: Quick wins (~3-4h)
- [ ] SearchScreen: autofocus + TextField od razu aktywny
- [ ] LocalInfoBar: ExpansionTile (zwinięty domyślnie) + timestamp "akt. X min temu"
- [ ] ScoresBar: tap → showModalBottomSheet z danymi meczu (wynik, minuta, status, liga, statystyki)
- [ ] ArticleCard: swipe actions (Dismissible) — right: zapisz/ulubione, left: ukryj/mniej

### Faza 2: Dashboard "Dzisiaj" (~4-5h)
- [ ] Nowy TodayDashboard (SliverAppBar + SliverList sekcji)
  - Top 3 news (wszystkie kategorie, interestScore + recency)
  - Kompaktowy pogoda/air
  - 2-3 mecze live/dziś
  - 1-2 "Dla Ciebie"
- [ ] W MainScreen: PageView[0] = TodayDashboard, [1] = CategoryNewsList, [2] = Saved

### Faza 3: Presety ustawień (~3-4h)
- [ ] UserPreset enum: simple, sport, local, news
- [ ] Każdy preset ustawia: themeVariant, selectedLeagueIds, enabledSourceIds, activeCategoryIds, preferredCity
- [ ] Settings: sekcja "Profil aplikacji" (4 kafelki), reszta w "Zaawansowane"

### Faza 4: Polish (~2-3h)
- [ ] Reader mode toggle w ArticleDetailScreen AppBar
- [ ] Prosta deduplikacja podobnych newsów (Jaccard/Levenshtein w _sortAndMixArticlesStatic)
- [ ] Cache timestamps na wszystkich kafelkach statycznych

## Nie ruszać (fundamenty — działają dobrze)
- PageView, Provider, Hive, kategorie, źródła, WebView jako fallback
- Publiczne API: RSS (137+), ESPN, TheSportsDB, OpenF1, Open-Meteo, NewsAPI.org
- BackgroundService (WorkManager), NotificationHistory, UserInterestService
