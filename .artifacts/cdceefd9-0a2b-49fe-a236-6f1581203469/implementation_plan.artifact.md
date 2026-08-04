# Strategiczny Plan Rozwoju i Szlifowania "Prasówki" (V5.0)

Ten plan ma na celu przekształcenie stabilnej bazy V4.7 w produkt o standardzie rynkowym (Premium UX). Zmiany będą wdrażane krok po kroku, a każdy etap wymaga Twojego zatwierdzenia.

## KROK 1: Wielkie Sprzątanie i Spójność (Stabilizacja)
Usunięcie ostatnich "duchów" w kodzie i ujednolicenie informacji systemowych.
- **Zadania:**
    - Usunięcie martwych stałych `enabledSportsKey` i `enabledLeaguesKey` z `SettingsProvider`.
    - Usunięcie nieużywanego mechanizmu `_fetchFailedIds` z `NewsProvider`.
    - Synchronizacja wersji w UI (Ustawienia) z faktycznym stanem projektu (`pubspec.yaml`).
    - Dodanie globalnego `try-catch` przy ładowaniu `WeatherService`, aby uniknąć "wiecznego kręcenia" przy braku sieci.

## KROK 2: Integracja Premium (In-App WebView)
Zamiast wyrzucać użytkownika do przeglądarki Chrome/Safari, sowa otworzy treści wewnątrz siebie.
- **Zadania:**
    - Dodanie paczki `webview_flutter`.
    - Stworzenie `ArticleWebViewScreen` dla linków sportowych (Flashscore) i przycisku "Czytaj oryginał".
    - Pozwala to zachować branding "Prasówki" i ułatwia powrót do listy newsów jednym gestem.

## KROK 3: Szlifowanie "Mojego Miasta" (UX Pogody i Newsów)
Naprawa linków lokalnych i rozszerzenie bazy informacji regionalnej.
- **Zadania:**
    - Zmiana statycznych linków GIOS w `LocalInfoBar` na dynamiczne zapytania Google (zgodnie z analizą).
    - Dodanie wizualnego oznaczenia (np. mała ikonka lokalizacji) przy newsach pochodzących z dynamicznego źródła miejskiego.
    - Ujednolicenie logiki `setPreferredCity`, aby nie dublowała się z `CategoryNewsList`.

## KROK 4: Inteligentna Gazeta (Nowe Funkcje)
Wprowadzenie elementów, które sprawią, że aplikacja będzie "mądrzejsza".
- **Zadania:**
    - **Wizualny status "Przeczytane"**: Przyciemnienie kart artykułów, które użytkownik już otworzył.
    - **Pasek "Dla Ciebie" na start**: Mały horyzontalny podgląd 3 top-rekomendacji na samej górze kategorii "Wszystkie".
    - **Optymalizacja Wartownika**: Zwiększenie częstotliwości sprawdzania wyników sportowych w tle (jeśli system na to pozwoli).

---

## Plan Działania
1. Każdy punkt realizujemy osobno.
2. Po zakończeniu punktu proszę Cię o weryfikację.
3. Wykonuję `commit` zmian.
4. Pytam o zgodę na przejście do kolejnego punktu.

**Czy akceptujesz ten harmonogram zmian? Jeśli tak, zaczniemy od KROKU 1 (Sprzątanie i Stabilizacja).** 🦉🛠️💎
