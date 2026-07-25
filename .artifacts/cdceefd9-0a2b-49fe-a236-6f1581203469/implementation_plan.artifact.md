# Plan Ostatecznego Czyszczenia Blokad (V4.2)

Ten plan eliminuje wszystkie potencjalne przeszkody w kodzie, które mogły blokować wyświetlanie wyników sportowych, oraz upraszcza architekturę zgodnie z nowymi wytycznymi użytkownika.

## Proposed Changes

### 1. Usunięcie Systemu "Enabled Sports"
Usuwamy resztki systemu ręcznego włączania dyscyplin, który mógł być głównym winowajcą "cichego blokowania" wyników.

#### [MODIFY] [settings_provider.dart](file:///D:/Apps/prasowka/lib/providers/settings_provider.dart)
- Usunięcie zmiennych `_enabledSports` i `_enabledLeagues`.
- Usunięcie metod `toggleSport` i `toggleLeague`.
- Wyczyszczenie inicjalizacji z tych kluczy.

#### [MODIFY] [sports_provider.dart](file:///D:/Apps/prasowka/lib/providers/sports_provider.dart)
- Usunięcie parametru `enabledSports` z metody `fetchEvents`.
- Usunięcie filtrowania po dyscyplinach w `_filterAndSortEvents`. Teraz przepuszczamy wszystko, co pasuje do zainteresowań.

### 2. Radar 14-dniowy (Szerokie Poszukiwania)
W związku z przesunięciem kalendarza 2026 -> 2024, rozszerzamy okno wyszukiwania dla lig, aby zapewnić ciągłość wyników.

#### [MODIFY] [sports_service.dart](file:///D:/Apps/prasowka/lib/services/sports_service.dart)
- **Zmiana okna**: W `_fetchLeagueEvents` filtrujemy mecze w zakresie **+/- 7 dni** od daty referencyjnej.
- **Pancerne Daty**: Poprawa parowania `dateEvent` i `strTime`. Jeśli czas jest błędny, ustawiamy domyślną godzinę 00:00, aby nie stracić meczu.

### 3. Finalne Uproszczenie UI (Settings)
#### [MODIFY] [settings_screen.dart](file:///D:/Apps/prasowka/lib/screens/settings_screen.dart)
- Usunięcie wszystkich odwołań do zarządzania dyscyplinami i ligami.
- Przycisk "Zarządzaj Kategoriami" w sekcji Edycja Wyboru Startowego zostanie zachowany, ale usuniemy resztę zbędnych elementów sportowych.

### 4. Usunięcie Martwego Kodu (Cleanup)
- Usunięcie nieużywanych metod `_fetchSoccerUniversal` i `_fetchSoccerRapidAPI` z `SportsService`.

## Verification Plan
1. **Hot Restart** jest kluczowy.
2. Sprawdzenie logów pod kątem: `Sowa Sports: Start V4.2 (No limits, purely interest-based)`.
3. Weryfikacja czy mecze Górnika (z okolic 26 lipca 2024) są widoczne na pasku.
