# Plan Naprawy V4.8: Dynamiczna Pogoda i Linki Lokalne

Ten plan rozwiązuje problem "uwiązania" kafelków pogodowych do Warszawy po ich kliknięciu oraz porządkuje nazewnictwo w kodzie.

## Proposed Changes

### 1. Dynamiczne Linki Pogodowe (LocalInfoBar)
Obecnie kliknięcie w kafelek otwiera statyczny URL `https://pogoda.interia.pl/`. Zmienimy to na dynamiczne zapytanie.

#### [MODIFY] [warsaw_info_bar.dart](file:///D:/Apps/prasowka/lib/widgets/warsaw_info_bar.dart)
- Zmiana nazwy klasy z `WarsawInfoBar` na `LocalInfoBar` (oraz odpowiednio w pliku).
- **Update `onTap` w kafelku pogody**: Użycie `https://www.google.com/search?q=pogoda+${settings.preferredCity}`.
- **Update `onTap` w kafelku powietrza**: Użycie `https://www.google.com/search?q=jakość+powietrza+${settings.preferredCity}`.
- To zagwarantuje, że przeglądarka od razu pokaże właściwe miasto.

### 2. Aktualizacja odniesień w CategoryNewsList
#### [MODIFY] [category_news_list.dart](file:///D:/Apps/prasowka/lib/widgets/category_news_list.dart)
- Zmiana wywołania widgetu z `const WarsawInfoBar()` na `const LocalInfoBar()`.

### 3. Drobne poprawki w SettingsProvider
#### [MODIFY] [settings_provider.dart](file:///D:/Apps/prasowka/lib/providers/settings_provider.dart)
- Upewnienie się, że `notifyListeners()` jest wywoływane natychmiast po zmianie miasta, aby kafelki zareagowały bez opóźnień.

## Verification Plan

### Manual Verification
1.  **Hot Restart** aplikacji.
2.  Zmiana miasta w ustawieniach na dowolne inne niż Warszawa (np. Poznań).
3.  Kliknięcie w kafelek pogody w odpowiedniej zakładce.
4.  Sprawdzenie, czy Google wyświetla prognozę dla Poznania.
5.  Powtórzenie testu dla kafelka jakości powietrza.
