# Strategiczny Plan Rozwoju i Szlifowania "Prasówki" (V5.0)

## KROK 1: Wielkie Sprzątanie i Spójność (ZREALIZOWANO V5.1)
- Usunięto martwe pola w Providerach.
- Zoptymalizowano częstotliwość Wartownika (1h).
- Zaktualizowano numery wersji.

## KROK 2: Integracja Premium — In-App WebView (ZREALIZOWANO V5.2)
- Dodano `webview_flutter`.
- Wdrożono `ArticleWebViewScreen` dla artykułów i wyników sportowych.

## KROK 3: Szlifowanie "Mojego Miasta" (W TRAKCIE V5.3)
Naprawa reaktywności i ujednolicenie UX dla funkcji lokalnych.
- **Zadania:**
    - **In-App WebView dla Pogody**: Przekierowanie kliknięć w kafelki temperatury/powietrza do wewnętrznej przeglądarki.
    - **Dynamiczne Linki**: Użycie `preferredCity` w zapytaniach Google, aby uniknąć wymuszania Warszawy.
    - **Ikonka Lokalizacji**: Dodanie 📍 przy źródłach RSS generowanych dynamicznie dla miast.
    - **Cleanup Nazewnictwa**: Zmiana `WarsawInfoBar` na `LocalInfoBar`.

## KROK 4: Inteligentna Gazeta (PLANOWANE V5.4)
- Wizualny status "Przeczytane" (przyciemnienie kart).
- Pasek horyzontalny "Dla Ciebie" na szczycie listy "Wszystkie".
