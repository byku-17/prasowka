# Plan Naprawy V3.0: Optymalizacja "Smart-Fetch"

Ten plan radykalnie zmienia strategię pobierania danych, aby zmieścić się w darmowych limitach RapidAPI (10 zapytań/min) i odblokować wyniki Ekstraklasy.

## Proposed Changes

### 1. Przebudowa SportsService (Zasada "Jeden Strzał")
Zamiast pętli po ligach, która generowała dziesiątki zapytań, Sowa pobierze wszystkie mecze z danego dnia jednym zapytaniem.

#### [MODIFY] [sports_service.dart](file:///D:/Apps/prasowka/lib/services/sports_service.dart)
- **Soccer (RapidAPI)**:
    - Użycie endpointu `/fixtures?date=YYYY-MM-DD`.
    - Pobieranie danych tylko dla 2 dni (Dziś i Wczoraj) – łącznie tylko 2 zapytania zamiast ~60.
    - Filtrowanie Ekstraklasy i innych lig wewnątrz aplikacji (pobieramy wszystko, wybieramy tylko to, co zaznaczył użytkownik).
- **Inne sporty (NHL, MLB, NFL)**:
    - Podobna optymalizacja: jedno zapytanie na dyscyplinę na dzień.
- **Dynamiczne sezony**: Zapytanie o datę nie wymaga podawania sezonu, co rozwiązuje problem błędnych lat (2024/2026).

### 2. Oszczędzanie Limitów w SportsProvider
#### [MODIFY] [sports_provider.dart](file:///D:/Apps/prasowka/lib/providers/sports_provider.dart)
- Wprowadzenie inteligentnego odświeżania: Jeśli dane z "Wczoraj" zostały już pobrane, nie pytamy o nie ponownie przy kolejnym odświeżeniu (pytamy tylko o "Dziś").

### 3. Logi Oszczędności
- Dodanie komunikatów informujących o zużyciu limitów: `Sowa Sports: Zaoszczędzono X zapytań dzięki filtrowaniu w locie`.

## Verification Plan
1. Wykonanie Hot Restartu.
2. Sprawdzenie logów: powinno pojawić się tylko kilka zapytań (np. 1 dla piłki, 1 dla NBA) zamiast długiej listy.
3. Weryfikacja czy Ekstraklasa z 24 lipca (piątek) jest widoczna jako "WCZORAJ".
