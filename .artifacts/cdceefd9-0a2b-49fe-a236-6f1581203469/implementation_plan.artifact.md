# Plan Implementacji Paska Wyników Sportowych (Live Scores)

Ten plan opisuje dodanie poziomego paska wyników meczów piłkarskich, zintegrowanego z API `football-data.org`, wyświetlanego na górze ekranu głównego.

## User Review Required

> [!IMPORTANT]
> **Ograniczenia API (Free Tier):**
> 1. Darmowy klucz `football-data.org` pozwala na 10 zapytań na minutę.
> 2. Darmowy pakiet obejmuje tylko główne ligi europejskie (m.in. Premier League, La Liga, Bundesliga, Serie A, Ligue 1, Liga Mistrzów). **Ekstraklasa nie jest dostępna w darmowym planie.**
> 3. Wymagane jest posiadanie klucza API. Na potrzeby deweloperskie użyjemy placeholdera, ale docelowo będziesz musiał go wkleić w kodzie.

## Proposed Changes

### 1. Model i Serwis Danych
Utworzenie nowej warstwy odpowiedzialnej za pobieranie i mapowanie wyników.

#### [NEW] [football_match.dart](file:///D:/Apps/prasowka/lib/models/football_match.dart)
- Klasa reprezentująca mecz (drużyny, wynik, status, logo).

#### [NEW] [football_service.dart](file:///D:/Apps/prasowka/lib/services/football_service.dart)
- Integracja z `http`.
- Metoda `fetchUpcomingMatches()` pobierająca dane dla wybranych lig.
- Mapowanie tekstowych nazw drużyn (z Twoich zainteresowań) na identyfikatory API.

### 2. Zarządzanie Stanem
Dodanie obsługi wyników do `NewsProvider` lub utworzenie dedykowanego providera.

#### [NEW] [scores_provider.dart](file:///D:/Apps/prasowka/lib/providers/scores_provider.dart)
- Przechowywanie listy meczów.
- Logika odświeżania co np. 15 minut (by nie przekroczyć limitów API).
- Filtrowanie meczów na podstawie Twoich słów kluczowych (np. jeśli masz "Real Madryt" w zainteresowaniach, ten mecz będzie pierwszy).

### 3. Interfejs Użytkownika (UI)
Dodanie paska wyników na ekranie głównym.

#### [NEW] [scores_bar.dart](file:///D:/Apps/prasowka/lib/widgets/scores_bar.dart)
- Pozioma, przewijalna lista małych kart z wynikami.
- Animacja "Live" dla trwających spotkań.

#### [MODIFY] [home_screen.dart](file:///D:/Apps/prasowka/lib/screens/home_screen.dart)
- Umieszczenie `ScoresBar` pomiędzy tytułem "PRASÓWKA" a paskiem kategorii.

### 4. Ustawienia
Możliwość włączenia/wyłączenia paska wyników.

#### [MODIFY] [settings_screen.dart](file:///D:/Apps/prasowka/lib/screens/settings_screen.dart)
- Dodanie przełącznika "Pokaż wyniki na żywo" w sekcji "Wygląd".

## Verification Plan

### Manual Verification
- Sprawdzenie, czy pasek wyświetla się tylko, gdy są dostępne mecze (lub "Brak meczów dzisiaj").
- Weryfikacja, czy mecze drużyn z listy "Moje zainteresowania" pojawiają się jako pierwsze.
- Sprawdzenie zachowania aplikacji przy braku internetu lub błędzie klucza API.
