# Plan Rozwoju V6.3: Finalna Kosmetyka "Dla Ciebie"

Ostatni etap planu "Ostatniego Szlifu" skupia się na perfekcyjnej integracji sekcji rekomendacji z listą newsów, aby wyeliminować przeskoki interfejsu (layout shifts) podczas ładowania danych.

## Proposed Changes

### 1. Stabilizacja Sekcji Rekomendacji (CategoryNewsList)
Głównym problemem jest nagłe pojawienie się paska "Dla Ciebie", gdy Sowa obliczy rekomendacje, co powoduje "skok" całej listy w dół.

#### [MODIFY] [category_news_list.dart](file:///D:/Apps/prasowka/lib/widgets/category_news_list.dart)
- **Zasada "Stałe Miejsce"**: Sekcja "DLA CIEBIE" będzie teraz stałym elementem listy w zakładce "Wszystkie", nawet jeśli rekomendacje są jeszcze obliczane.
- **Płynne Przejście**: Użycie `AnimatedSwitcher` lub prostej animacji opacity, aby rekomendacje pojawiały się płynnie, a nie "wskakiwały" gwałtownie.
- **Placeholder**: Dodanie delikatnego, niskiego shimmery/placeholdera w miejscu rekomendacji podczas ładowania pierwszej paczki newsów.

### 2. Spójność Wizualna Nagłówków
#### [MODIFY] [category_news_list.dart](file:///D:/Apps/prasowka/lib/widgets/category_news_list.dart)
- Ujednolicenie stylu napisu "NAJNOWSZE WIADOMOŚCI" z sekcją "DLA CIEBIE" (font-size, letter-spacing).
- Poprawa marginesów, aby lista wyglądała jak spójna, nowoczesna gazeta.

### 3. Finalna Weryfikacja Wersji
- Aktualizacja wersji na `1.4.0 (V6.3 Final Release Candidate)`.

## Verification Plan

### Manual Verification
1.  **Hot Restart** aplikacji.
2.  Wejdź w zakładkę **WSZYSTKIE**.
3.  Zwróć uwagę, czy lista "skacze", gdy pojawiają się rekomendacje. Powinny one pojawić się płynnie bez przesuwania Twojego wzroku.
4.  Sprawdź, czy przyciemnianie przeczytanych artykułów (z Kroku 4) współgra z nowym wyglądem listy.
