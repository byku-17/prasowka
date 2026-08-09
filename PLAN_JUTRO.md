# Plan na jutro — 08.08.2026

## Priorytet 0: Nowe funkcje (dopisane w trakcie) 🚧
- [ ] Rozmiar czcionki czytania (tłumacz z `readingFontSize`) — dodać UI w WYGLĄD
- [ ] Wyszukiwarka ustawień z synonimami (np. "motyw", "wygląd", "skóra")
- [x] Sekcja "O aplikacji" (wersja przez package_info_plus, polityka prywatności, kontakt, licencje)
- [x] Wyczyść pamięć podręczną w DANE I NARZĘDZIA (`clearNewsCache`)

## Priorytet 0b: Reorganizacja ustawień ✅
- [x] KONTO — Zaloguj/Zarejestruj, Synchronizuj, Pobierz z chmury, Wyloguj
- [x] WYGLĄD — tylko motyw (jasny/ciemny/fioletowy)
- [x] POWIADOMIENIA — Wartownik Sowy + pasek sportowy włącz/wyłącz
- [x] TREŚCI — Źródła RSS, Kategorie, Zainteresowania (słowa kluczowe), Tagi
- [x] SPORT — ulubione drużyny/ligi, "tylko moi faworyci", diagnostyka
- [x] DANE I NARZĘDZIA — Eksport, Import, Wyczyść cache
- [x] O APLIKACJI — wersja, polityka prywatności, kontakt, licencje

## Priorytet 1: Historia przeglądania ✅
- [x] Ekran "Historia" lub sekcja w "Zapisane" z listą przeczytanych artykułów
- [x] Sortowanie po czasie czytania (od najnowszego)
- [x] Czyszczenie historii (automatyczne po 7/30 dni lub ręczne)
- [x] Ręczne usuwanie pojedynczych wpisów

## Priorytet 2: Ustrukturyzowanie ustawień ✅
- [x] Podział na sekcje: Konto, Motywy, Powiadomienia, Źródła, Sport, Prywatność
- [x] Eksport/import ustawień (backup do pliku)
- [x] Wyszukiwarka w ustawieniach
- [ ] Toggle "tryb oszczędzania baterii" (rzadsze odświeżanie w tle) — do zrobienia

## Priorytet 3: Usprawnienia UI/UX ✅
- [x] Pull-to-refresh na ekranie "Dzisiaj" (odśwież feed)
- [x] Animacje przejść między ekranami (hero animations na zdjęciach)
- [x] Ciemny motyw auto-sync z systemem (nie tylko ręczny toggle)
- [x] Swipe do przodu/tyłu w artykule (poprzedni/następny artykuł z listy)

## Priorytet 4: Sport — dalszy rozwój
- Wykrywanie golu w meczach live (powiadomienie push)
- Wykrywanie końca meczu (automatyczne odświeżenie wyniku)
- Porównanie składów przed meczem (dane z API)
- Statystyki H2H (head-to-head) w bottom sheet meczu

## Priorytet 5: Wydajność
- Lazy loading artykułów w feed (paginacja zamiast ładowania wszystkiego)
- Cache obrazków z TTL (automatyczne czyszczenie po 7 dniach)
- Optymalizacja Hive — batch writes zamiast pojedynczych put
- Redukcja rebuildów widgetów (Selector zamiast Consumer tam gdzie możliwe)

## Priorytet 6: nowe funkcje
- Udostępnianie artykułów jako zrzut ekranu (share as image)
- Tagowanie artykułów (własne tagi: "do przeczytania", "ważne", "inspiracja")
- Tryb czytania (czcionka do wyboru: mała/średnia/duża)
- Tłumaczenie artykułów offline (cache przetłumaczonych treści)
- Widget ekranu głównego (ostatnie artykuły z news feed)

## Priorytet 7: Stabilność
- Automatyczne raportowanie błędów (crashlytics)
- Testy integracyjne (płynność przejść między ekranami)
- Monitorowanie zużycia baterii przez background service
- Optymalizacja rozmiaru aplikacji (obrazki WebP, kompresja assets)

---

## Zadania z "na jutro" (09.08.2026) ✅

## 1. Odświeżanie strony po kliknięciu w nazwę zakładki/ekranu ✅
- [x] Kliknięcie aktywnej zakładki w bottom nav odświeża feed (`refreshNotifier`)

## 2. Zwiększenie udziału artykułów tech/motoryzacja itp. w zakładce "Dzisiaj" ✅
- [x] Mix kategorii tech/science/automotive/travel/culture co 3–4 posty (boost po categoryId)

## 3. Przyciski pod artykułami ✅
- [x] Lista: łapka góra/dół + bookmark (tap = "do przeczytania", long-press = lista tagów)
- [x] Detail: łapki + przycisk tagów otwierający listę od razu
