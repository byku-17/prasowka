# Plan: Sowa 2.0 - Punkt 2: Onboarding i Silnik Google News RSS

Celem tego etapu jest wdrożenie profesjonalnego okna powitalnego oraz mechanizmu dynamicznego pobierania newsów na podstawie słów kluczowych (firmy, drużyny) za pomocą nielimitowanego Google News RSS.

## User Review Required

> [!IMPORTANT]
> **Dynamiczne Źródła:** Każde słowo kluczowe wpisane w Onboardingu (lub później w ustawieniach) stworzy "wirtualne źródło" Google News. Dzięki temu sowa znajdzie informacje o Twojej ulubionej firmie czy lokalnej drużynie, nawet jeśli nie ma ich na naszej liście 130 portali.
> **Pierwsze Wrażenie:** Przywrócimy ekran powitalny, który tym razem będzie poprawnie zintegrowany z systemem ładowania danych.

## Proponowane Zmiany

### 1. Aktywacja Onboardingu (UI Flow)

#### [MODIFY] [splash_screen.dart](file:///D:/Apps/prasowka/lib/screens/splash_screen.dart)
- Przywrócenie warunkowej nawigacji: `onboardingCompleted ? MainScreen : OnboardingScreen`.
- Naprawa błędu z `const` przy dynamicznym wyborze ekranu.

### 2. Silnik Google News RSS (Logic)

#### [MODIFY] [providers/settings_provider.dart](file:///D:/Apps/prasowka/lib/providers/settings_provider.dart)
- Rozszerzenie metody `addTeam` (którą zmienimy na `addKeyword`).
- **Logika:** Po dodaniu słowa sowa automatycznie generuje link RSS: `news.google.com/rss/search?q={keyword}&hl=pl&gl=PL&ceid=PL:pl`.
- Dodawanie takich linków jako specjalnych `NewsSource` do bazy Hive.

#### [MODIFY] [providers/news_provider.dart](file:///D:/Apps/prasowka/lib/providers/news_provider.dart)
- Priorytetyzacja artykułów pochodzących z "wyszukiwarek Google" na górze listy w sekcji "Dla Ciebie".

### 3. Finalizacja Onboarding Screen (UI)

#### [MODIFY] [screens/onboarding_screen.dart](file:///D:/Apps/prasowka/lib/screens/onboarding_screen.dart)
- Upewnienie się, że przycisk "ZACZNIJMY!" poprawnie zapisuje wszystkie dane i przechodzi do `MainScreen`.
- Dodanie animacji przejścia między krokami.

## Plan Weryfikacji

### Testy Funkcjonalne
1. **Reset Danych:** Wyczyszczenie danych aplikacji i sprawdzenie, czy sowa wita nas ekranem Onboarding.
2. **Keyword Test:** Wpisanie unikalnego słowa (np. nazwy rzadkiej kryptowaluty) w onboardingu i sprawdzenie, czy newsy o tym faktycznie pojawiają się na górze listy po starcie.
3. **Skip Test:** Sprawdzenie, czy po przejściu onboardingu sowa przy kolejnym starcie od razu pokazuje newsy (Splash -> Main).
