# Plan Naprawy V4.9: Precyzyjna Pogoda i Bezpośrednie Linki

Ten plan rozwiązuje dwa problemy: błąd braku temperatury dla Warszawy oraz potrzebę przechodzenia do konkretnych stron z danymi pogodowymi zamiast ogólnego wyszukiwania w Google.

## Proposed Changes

### 1. Naprawa logiki odświeżania (LocalInfoBar)
Obecna logika wywołuje odświeżanie danych wewnątrz metody `build()`, co jest błędem w architekturze Fluttera i może prowadzić do przerywania zapytań sieciowych lub błędnego stanu (stąd brak temperatury dla Warszawy).

#### [MODIFY] [local_info_bar.dart](file:///D:/Apps/prasowka/lib/widgets/local_info_bar.dart)
- **Usunięcie `_checkAndFetch` z `build()`**: Przeniesienie logiki sprawdzania zmiany miasta do `didChangeDependencies()` oraz bezpieczne wywoływanie fetchowania przez `Future.microtask` lub `addPostFrameCallback`.
- **Stabilizacja stanu**: Upewnienie się, że `_isLoading` i `_hasError` są poprawnie resetowane przy każdej zmianie miasta.

### 2. Bezpośrednie linki do danych (Onet i AQICN)
Zastąpimy wyszukiwarkę Google linkami prowadzącymi bezpośrednio do szczegółowych prognoz.

#### [MODIFY] [local_info_bar.dart](file:///D:/Apps/prasowka/lib/widgets/local_info_bar.dart)
- **Pogoda**: Użycie `https://pogoda.onet.pl/[miasto]` (np. `https://pogoda.onet.pl/warszawa`).
- **Jakość powietrza**: Użycie `https://aqicn.org/city/poland/[miasto]` (np. `https://aqicn.org/city/poland/warsaw`).
- **Mapowanie nazw**: Dodanie pomocniczej metody mapującej polskie nazwy na bezpieczne "URL-friendly" odpowiedniki (np. Łódź -> lodz, Warszawa -> warsaw dla AQICN).

### 3. Poprawa odporności WeatherService
#### [MODIFY] [weather_service.dart](file:///D:/Apps/prasowka/lib/services/weather_service.dart)
- **Parsowanie**: Ulepszenie konwersji typów (double/int), aby uniknąć błędów, gdy API zwróci np. `15` zamiast `15.0`.
- **Logging**: Dodanie szczegółowych logów przy błędach sieciowych, aby ułatwić diagnostykę.

## Verification Plan

### Manual Verification
1.  **Hot Restart** aplikacji.
2.  Sprawdzenie, czy dla Warszawy wyświetla się temperatura.
3.  Kliknięcie w kafelek temperatury -> weryfikacja czy otwiera się strona Onet Pogoda dla Warszawy wewnątrz aplikacji.
4.  Kliknięcie w kafelek powietrza -> weryfikacja czy otwiera się AQICN dla Warszawy.
5.  Zmiana miasta na **Łódź** i powtórzenie testów (weryfikacja czy linki i dane reagują na zmianę).
