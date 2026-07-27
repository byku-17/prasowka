# Plan Naprawy V4.5: Odblokowanie i Discovery Mode

Ten plan ostatecznie usuwa blokady w interfejsie i wprowadza inteligentny tryb wyświetlania meczów, gdy Twoi faworyci odpoczywają.

## Proposed Changes

### 1. Odblokowanie Paska Wyników (ScoresBar)
Główny winowajca braku wyników. Zmieniamy logikę wyświetlania na "Interest-First".

#### [MODIFY] [scores_bar.dart](file:///D:/Apps/prasowka/lib/widgets/scores_bar.dart)
- **Koniec z blokadą lig**: Pasek będzie wyświetlał WSZYSTKIE mecze przekazane przez `SportsProvider`.
- Ustawienia `selectedLeagueIds` będą służyć tylko jako DODATKOWE mecze (jeśli chcesz śledzić całą ligę, a nie tylko klub).
- Jeśli mecz pasuje do Twoich zainteresowań, pojawi się na pasku bez względu na to, czy liga jest "ptaszkowana".

### 2. Ujednolicona "Podróż w czasie" (SportsService)
#### [MODIFY] [sports_service.dart](file:///D:/Apps/prasowka/lib/services/sports_service.dart)
- Naprawa Tenisa: Wymuszenie daty 2024 dla endpointu `eventsday.php`.
- Naprawa F1: Dynamiczne obliczanie progu "następnego wyścigu" w oparciu o `referenceNow`.

### 3. Tryb Discovery (Hity Dnia)
Jeśli po przefiltrowaniu pod zainteresowania lista jest pusta, sowa nie pokaże "Brak meczów", lecz "Hity Dnia" (topowe mecze ze świata).

#### [MODIFY] [sports_provider.dart](file:///D:/Apps/prasowka/lib/providers/sports_provider.dart)
- Implementacja logiki `Discovery`: jeśli `_events` po filtrach == 0, ale `newEvents` > 0 -> weź 5 najważniejszych meczów (np. z najwyższym ID ligi / Premier League) i oznacz je jako propozycje.

### 4. Cleanup SettingsProvider
#### [MODIFY] [settings_provider.dart](file:///D:/Apps/prasowka/lib/providers/settings_provider.dart)
- Usunięcie martwych stałych `enabledSportsKey` i `enabledLeaguesKey`.

## Verification Plan
1. **Hot Restart**.
2. Wejdź w **SPORT**. Nawet bez wybierania lig w ustawieniach, powinieneś zobaczyć wyniki, jeśli masz wpisane kluby w zainteresowaniach.
3. Jeśli nie masz zainteresowań -> powinieneś zobaczyć "Hity Dnia" zamiast pustki.
