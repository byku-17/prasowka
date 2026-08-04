# Plan Naprawy V4.9.1: Profesjonalne Linki Pogodowe (Windy & Airly)

Ten plan rozwiązuje problemy z niedziałającymi linkami (404) oraz błędnymi przekierowaniami (Indie) poprzez zmianę źródeł na takie, które obsługują współrzędne geograficzne.

## Proposed Changes

### 1. Zmiana źródeł linków (LocalInfoBar)
Rezygnujemy z Onetu i AQICN na rzecz bardziej precyzyjnych i stabilnych serwisów.

#### [MODIFY] [local_info_bar.dart](file:///D:/Apps/prasowka/lib/widgets/local_info_bar.dart)
- **Pogoda**: Zmiana na **Windy.com**.
    - URL: `https://www.windy.com/${city.latitude}/${city.longitude}`.
    - Windy automatycznie centruje mapę i prognozę na podanych współrzędnych.
- **Jakość Powietrza**: Zmiana na **Airly.org**.
    - URL: `https://airly.org/map/pl/#${city.latitude},${city.longitude}`.
    - Airly to lider polskiego monitoringu smogu, link z GPS jest niezawodny.

### 2. Naprawa inicjalizacji (Warszawa)
#### [MODIFY] [local_info_bar.dart](file:///D:/Apps/prasowka/lib/widgets/local_info_bar.dart)
- Upewnienie się, że `_lastCityHash` nie blokuje pierwszego pobrania danych dla domyślnego miasta (Warszawa).
- Dodanie logu: `Sowa Weather: Pobieram dane dla ${city.name}` do konsoli dla łatwiejszego debugowania.

### 3. Usunięcie niepotrzebnego mapowania "Slug"
- Metoda `_getCitySlug` zostanie usunięta, ponieważ Windy i Airly nie potrzebują już transliteracji nazw (korzystają z GPS).

## Verification Plan

### Manual Verification
1.  **Hot Restart** aplikacji.
2.  Sprawdzenie, czy dla Warszawy wyświetla się temperatura.
3.  Kliknięcie w kafelek temperatury -> weryfikacja czy otwiera się **Windy.com**.
4.  Kliknięcie w kafelek powietrza -> weryfikacja czy otwiera się mapa **Airly**.
5.  Zmiana miasta na **Łódź** lub **Kraków** i weryfikacja czy linki Windy/Airly poprawnie przekazują nowe współrzędne.
