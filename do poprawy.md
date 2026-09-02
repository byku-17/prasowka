# Prasówka — Audyt i Plan Naprawy

> Wygenerowano: 2026-09-02
> Stan: Wszystkie niskopriorytetowe naprawione. Pozostały tylko odłożone (wymagają więcej pracy).

---

## Zakończone (5 commitów)

| Faza | Commit | Zmiany |
|------|--------|--------|
| 1 Bezpieczeństwo | `a4a7288` | C2, H3, H2, H5 |
| 2 Wydajność | `a4a7288` | H7, H8, H9, H6 |
| 3 Architektura | `ee9fa42` | M1, M4, M9, M13 |
| 4 Optymalizacja | `2ea4911` | M7, M12, M14, M11 |
| 5 Czyszczenie | `4828392` | L2, L3+L4, L5 |

### Szczegły napraw

#### Faza 1: Bezpieczeństwo
- **C2** — Google Sign-In nie używa UID jako klucza szyfrowania (`auth_screen.dart`, `main.dart`). Sync bez szyfrowania dla Google do momentu ustawienia PINu.
- **H3** — `google-services.json` usunięty z trackingu git, dodany do `.gitignore`.
- **H2** — WebView `onNavigationRequest` blokuje `intent://`, `file://` itp. (`article_webview_screen.dart`).
- **H5** — `StorageService._openSafe` — retry 3× z backoff zamiast kasowania skorumpowanych boxów (`storage_service.dart`).

#### Faza 2: Wydajność
- **H7** — `preloadInterests()` przed pętlami scoringowymi — 6000 Hive reads → 1 (`user_interest_service.dart`, `news_provider.dart`, `background_service.dart`).
- **H8** — `ValueNotifier<int>` zamiast `setState` przy scrollu — brak full rebuild (`article_detail_screen.dart`).
- **H9** — Cache `_unreadCount` w `NotificationHistory` — O(1) zamiast O(n) deserializacji (`notification_history.dart`).
- **H6** — `fullContent` truncate do 10K znaków w cache — ~8MB oszczędności (`storage_service.dart`).

#### Faza 3: Architektura
- **M1** — Direct Hive reads w `news_provider` podmienione na `SettingsProvider` (`news_provider.dart`, `main.dart`).
- **M4** — `StreamSubscription` leaks naprawione w `AuthService` (authSub) i `SettingsProvider` (connectivity cancel w dispose).
- **M9** — `PageView.builder` zamiast `PageView(children:)` w `main_screen.dart`.
- **M13** — Równoległa inicjalizacja `RemoteConfig + Hive + HttpClient` w `main.dart`.

#### Faza 4: Optymalizacja
- **M7** — `today_screen` i `category_tab_screen` używają cache'owanego `recommendedArticles` zamiast rekomputować w builderze.
- **M12** — Background service: fetch RSS raz, wyniki do `_handleRssNotifications` i `_handleDailySummary` (`background_service.dart`).
- **M14** — In-memory cache `_categoryCacheMemory` w `StorageService` — unika deserializacji 200 artykułów.
- **M11** — `AnimationController` w `_PulsingBrowserButton` — `repeat()` tylko gdy `pulse=true`, `stop()` gdy `pulse=false`.

#### Faza 5: Czyszczenie
- **L2** — Usunięty nieużywany `CanonicalKey.isSameMatch()`.
- **L3+L4** — Usunięte nieużywane `resetAllCooldowns()` i `getDiagnostics()` w `SportsRequestQueue`.
- **L5** — `TextUtils.stripPolish()` wyciągnięte jako wspólna metoda, 3 kopii normalizacji → 1.

---

## Pozostałe — Niski priorytet

### L6. Deprecated `readLater` field
- **Plik:** `lib/models/article.dart:35`
- **Problem:** Pole `readLater` jest deprecated w Hive schema, ale wciąż istnieje.
- **Status:** ⏭️ Pominięte — `@HiveField(9)`, usunięcie złamałoby deserializację istniejących danych.

### L7. Stare skrypty w `tool/`
- **Plik:** `tool/*.dart` (6 plików)
- **Problem:** Jednorazowe skrypty migracyjne, nieużywane.
- **Status:** ✅ Usunięte (6 plików + katalog).

### L8. `_cachedTags` cache nigdy invalidowany
- **Plik:** `lib/models/article.dart:65`
- **Problem:** Cache tagów na obiekcie Article — nigdy nie jest czyszczony.
- **Status:** ✅ Usunięty cache (title/description i tak nie są mutowane).

### L9. Brak `allowBackup="false"` w AndroidManifest
- **Plik:** `android/app/src/main/AndroidManifest.xml`
- **Problem:** ADB backup może odczytać dane aplikacji (Hive boxes).
- **Status:** ✅ Dodano `android:allowBackup="false"`.

### L10. `_extractIV` fallback do stored IV
- **Plik:** `lib/services/encryption_service.dart:202`
- **Problem:** Przy niepowodzeniu parse IV z ciphertext, fallbackuje do stored IV — może deszyfrować złymi danymi.
- **Status:** ✅ Usunięty fallback, teraz rzucany jest `StateError`.

### L11. Shuffle z Deterministic PRNG
- **Plik:** `lib/providers/news_provider.dart:426`
- **Problem:** `List.shuffle()` bez seed — każdy refresh daje inną kolejność (mieszanie jest losowe, nie deterministyczne).
- **Status:** ⏭️ Pominięte — losowe mieszanie jest zamierzone (unikanie monotoniczności).

### L12. `articleRetentionDays` hardcoded source IDs
- **Plik:** `lib/providers/settings_provider.dart:386`
- **Problem:** Retencja_ARTICLE jest powiązana z hardcoded source IDs.
- **Naprawa:** Parametryzować lub przenieść do ustawień.

### L13. `HttpClient` zwraca null zamiast exception
- **Plik:** `lib/services/http_client.dart:30`
- **Problem:** `get` zwraca `null` przy błędzie zamiast rzucać exception.
- **Naprawa:** Zwracać `HttpClientException` lub zawsze zwracać Response.

### L14. Brak iOS ATS config
- **Plik:** `ios/Runner/Info.plist`
- **Problem:** Brak `NSAppTransportSecurity` — iOS może blokować HTTP.
- **Naprawa:** Dodać ATS config z exception dla domainów RSS (jeśli nie HTTPS).

### L15. HtmlWidget bez kluczy w pętli
- **Plik:** `lib/screens/article_detail_screen.dart:661`
- **Problem:** `HtmlWidget` w pętli `for` bez `Key` — Flutter może źle repaintingować.
- **Status:** ✅ Dodano `key: ValueKey('chunk_$i')`.

### L16. Brak `@immutable` na modelach w Selector
- **Plik:** `lib/models/article.dart`, `lib/models/sport_event.dart`
- **Problem:** Modele używane w `Selector` nie mają adnotacji `@immutable` — Flutter nie może optymalizować comparisions.
- **Status:** ⏭️ Pominięte — `Article` extends `HiveObject` (mutowalny), `@immutable` byłby misleading.

### L17. `debugPrint` w 91 miejscach
- **Pliki:** 20+ plików
- **Problem:** Brak kontroli nad logowaniem — debugPrint w produkcji.
- **Naprawa:** Wprowadzić logger framework (np. `logging` package) z poziomami (debug/info/warning) i compatibility z Crashlytics.

---

## Pozostałe — Odłożone (wymagają więcej pracy)

### H1. Hive encryption (szyfrowanie local storage)
- **Problem:** Hive boxes niezaszyfrowane na dysku. Odczytalne przez ADB backup / rooted device.
- **Wymagania:**
  - Klucz w Secure Storage (DEK lub device-local key)
  - Migracja istniejących niezaszyfrowanych boxów → zaszyfrowane
  - Współdzielenie klucza z background izolatem (Workmanager)
  - Klucz device-local dla niezalogowanych użytkowników
  - Backup przed migracją na wypadek błędu
- **Ryzyko:** Utrata danych przy nieudanej migracji.
- **Szacunek:** 2-3h pracy + testy na różnych wersjach Android/iOS.

### M2. Mix singleton/new dla serwisów (brak DI)
- **Problem:** `NewsProvider` tworzy serwisy inline (`RssService()`, `ReaderService()`, itp.) zamiast otrzymywać je przez konstruktor.
- **Naprawa:** Wprowadzić constructor injection lub package `get_it`/`riverpod`.
- **Szacunek:** 3-4h refaktoringu.

### M6. SettingsProvider — God Class (842 linii)
- **Problem:** Jeden provider zarządza: theme, categories, sources, sports, notifications, reading, sync, tabs.
- **Naprawa:** Rozbić na: `ThemeProvider`, `CategoryProvider`, `NotificationSettingsProvider`, `ReadingSettingsProvider`.
- **Szacunek:** 4-6h refaktoringu + testy.

### M15. API key w URL query string
- **Plik:** `lib/services/news_api_service.dart:26`
- **Problem:** `?apiKey=KEY` w URL — logi serwera, historii przeglądarki mogą go przechwycić.
- **Naprawa:** Przenieść do header `X-Api-Key`.
- **Szacunek:** 30min (klient) + weryfikacja serwera.

### M16. Cleartext HTTP dla 6 domen
- **Plik:** `android/app/src/main/res/xml/network_security_config.xml`
- **Problem:** 6 domen RSS bez HTTPS.
- **Naprawa:** Migracja feedów na HTTPS (sprawdzić które domeny obsługują).
- **Szacunek:** 1-2h (weryfikacja + zmiana URLi).

### M17. Brak certificate pinning
- **Plik:** `lib/services/http_client.dart`
- **Problem:** Brak pinningu — MITM może przechwycić ruch.
- **Naprawa:** Pin critical endpoints (Firebase, NewsAPI) z `certificate_pinning` package.
- **Szacunek:** 1-2h.

### M18. Hasło w pamięci bez terminu ważności
- **Plik:** `lib/services/sync_service.dart:31`
- **Problem:** `_encryptionPassword` w pamięci — żyje przez cały lifetime sesji.
- **Status:** ✅ Clear po 30min TTL (`passwordTtl`).

### M19. Słaby email validation
- **Plik:** `lib/screens/auth_screen.dart:114`
- **Problem:** Walidacja tylko `v.contains('@')`.
- **Status:** ✅ Regex: `^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`.

### M20. HTML parsing dla obrazków — pełne DOM
- **Plik:** `lib/services/rss_service.dart:150-155`
- **Problem:** Parsowanie HTML przez pełny DOM dla wyodrębnienia obrazków.
- **Status:** ✅ Regex zamiast `parse()` dla image extraction.

---

## Podsumowanie statystyczne

| Kategoria | CRITICAL | HIGH | MEDIUM | LOW |
|-----------|----------|------|--------|-----|
| Zakończone (Fazy 1-5) | 2 | 7 | 9 | 5 |
| Zakończone (quick fixes) | 0 | 0 | 3 | 5 |
| Pominięte (niemożliwe/bezpieczne) | 0 | 0 | 0 | 3 |
| Odłożone (wymagają więcej pracy) | 0 | 1 | 8 | 0 |
| **Łącznie** | **2** | **8** | **17** | **13** |

---

## Rekomendowana kolejność

1. **M19** — Słaby email regex (10min)
2. **L9** — `allowBackup="false"` (5min)
3. **L15** — HtmlWidget keys w pętli (10min)
4. **L16** — `@immutable` na modelach (20min)
5. **M18** — Clear hasło po sync (30min)
6. **M13** — (już zrobione)
7. **L10** — Usunąć fallback IV (30min)
8. **M20** — Regex zamiast DOM dla obrazków (30min)
9. **L7** — Usunąć tool/*.dart (5min)
10. **H1** — Hive encryption (2-3h, wymaga planu migracji)
