# Plan na jutro — 08.08.2026

## Priorytet 1: Historia przeglądania
- Ekran "Historia" lub sekcja w "Zapisane" z listą przeczytanych artykułów
- Sortowanie po czasie czytania (od najnowszego)
- Możliwość oznaczenia jako "przeczytane" ręcznie
- Czyszczenie historii (automatyczne po 7/30 dni lub ręczne)
- Ikona "godzinka" w nawigacji lub w menu bocznym

## Priorytet 2: Ustrukturyzowanie ustawień
- Podział na sekcje: Konto, Motywy, Powiadomienia, Źródła, Sport, Prywatność
- Toggle "tryb oszczędzania baterii" (rzadsze odświeżanie w tle)
- Eksport/import ustawień (backup do pliku)
- Wyszukiwarka w ustawieniach

## Priorytet 3: Usprawnienia UI/UX
- Pull-to-refresh na ekranie "Dzisiaj" (odśwież feed)
- Animacje przejść między ekranami (hero animations na zdjęciach)
- Ciemny motyw auto-sync z systemem (nie tylko ręczny toggle)
- Swipe do przodu/tyłu w artykule (poprzedni/następny artykuł z listy)

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
