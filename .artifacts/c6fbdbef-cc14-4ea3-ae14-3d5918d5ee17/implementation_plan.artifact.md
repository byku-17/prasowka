# Plan: Ekstremalna Optymalizacja Wydajności (Speed & Cache)

Użytkownik zgłosił bardzo powolne ładowanie artykułów. Przy blisko 130 źródłach RSS, obecny model "pobierz wszystko naraz i czekaj" paraliżuje łącze i procesor telefonu. Wprowadzimy architekturę **"Offline First"** oraz wielowątkowe przetwarzanie danych.

## User Review Required

> [!IMPORTANT]
> **Zmiana zachowania UI:** Po zmianie zakładki newsy pojawią się **natychmiast** (z pamięci podręcznej), a kółko ładowania będzie kręcić się subtelnie w tle, aktualizując listę, gdy nowe dane spłyną z sieci.

> [!WARNING]
> Pierwsze uruchomienie po aktualizacji może zająć chwilę na migrację bazy danych Hive, ale każde kolejne będzie błyskawiczne.

## Proponowane Zmiany

### 1. Warstwa Danych i Cache (StorageService)

#### [MODIFY] [storage_service.dart](file:///D:/Apps/prasowka/lib/services/storage_service.dart)
- Dodanie nowego "pudełka" Hive: `news_cache`.
- Metody `saveToCache(String categoryId, List<Article> articles)` oraz `loadFromCache(String categoryId)`.
- Automatyczne czyszczenie starych wpisów w cache, aby aplikacja nie zajmowała gigabajtów danych.

### 2. Wielowątkowość i Sieć (RssService)

#### [MODIFY] [rss_service.dart](file:///D:/Apps/prasowka/lib/services/rss_service.dart)
- **Isolates (Wielowątkowość):** Przeniesienie ciężkiego parsowania XML/RSS do osobnego wątku procesora (`compute`). Zapobiegnie to "zamrażaniu" animacji (jank) podczas ładowania 100+ newsów.
- **Batching:** Implementacja pobierania w małych grupach (np. 5 źródeł jednocześnie), aby nie zapchać kolejki sieciowej systemu operacyjnego.

### 3. Logika "Instant UI" (NewsProvider)

#### [MODIFY] [news_provider.dart](file:///D:/Apps/prasowka/lib/providers/news_provider.dart)
- **Logika Cache First:** Podczas `fetchNews`, najpierw ładujemy dane z Hive i natychmiast robimy `notifyListeners()`. Użytkownik widzi treść w ułamku sekundy.
- **Background Update:** Po wyświetleniu cache, sowa w tle pobiera świeże dane. Jeśli znajdzie nowsze artykuły, podmienia listę.

### 4. Ulepszenia Interfejsu (UI)

#### [MODIFY] [home_screen.dart](file:///D:/Apps/prasowka/lib/screens/home_screen.dart)
- Dodanie wizualnego wskaźnika ładowania w tle (np. mały pasek postępu pod AppBar), zamiast blokowania całego ekranu dużym Spinnerem.

## Plan Weryfikacji

### Testy Manualne
1. **Test Startu:** Zamknięcie aplikacji i ponowne otwarcie. Newsy na zakładce "Wszystkie" powinny pojawić się bez widocznego ładowania.
2. **Test Płynności:** Przewijanie listy podczas gdy w tle trwa pobieranie nowych danych — weryfikacja braku przycięć (jank).
3. **Test Offline:** Uruchomienie aplikacji bez internetu — sowa powinna pokazać ostatnio pobrane newsy z cache.
