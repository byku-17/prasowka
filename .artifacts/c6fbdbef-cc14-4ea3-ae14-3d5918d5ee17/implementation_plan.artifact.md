# Plan: Bezpieczeństwo i Pamięć Stanu (Ochrona przed wyjściem)

Celem jest ochrona użytkownika przed przypadkowym zamknięciem aplikacji oraz sprawienie, by sowa pamiętała, na czym skończyłeś czytanie.

## User Review Required

> [!IMPORTANT]
> **Podwójny "Wstecz":** Na głównym ekranie sowa nie zamknie się po jednym kliknięciu przycisku wstecz. Wyświetli komunikat "Kliknij jeszcze raz, aby wyjść". Drugie kliknięcie w ciągu 2 sekund zamknie aplikację.
> **Pamięć Zakładki:** Sowa zapamięta, którą kategorię przeglądałeś (np. Sport) i przy następnym uruchomieniu otworzy ją automatycznie zamiast zawsze startować od "Wszystkich".

## Proponowane Zmiany

### 1. Ochrona przed wyjściem (UI Logic)

#### [MODIFY] [screens/main_screen.dart](file:///D:/Apps/prasowka/lib/screens/main_screen.dart)
- Owinięcie `Scaffold` w `PopScope`.
- Implementacja logiki `_onWillPop`: jeśli użytkownik nie jest na pierwszej zakładce, powrót do pierwszej. Jeśli jest na pierwszej — prośba o drugie kliknięcie.

### 2. Pamięć ostatniej lokalizacji (Logic)

#### [MODIFY] [providers/settings_provider.dart](file:///D:/Apps/prasowka/lib/providers/settings_provider.dart)
- Dodanie pola `lastTabIndex` do ustawień zapisywanych w Hive.
- Metoda `setLastTabIndex(int index)`.

#### [MODIFY] [screens/main_screen.dart](file:///D:/Apps/prasowka/lib/screens/main_screen.dart)
- Wczytywanie początkowego indeksu z `SettingsProvider`.
- Zapisywanie indeksu przy każdej zmianie zakładki.

### 3. Szybki powrót do artykułu (UX)

Sowa już teraz trzyma artykuły w cache, więc powrót do listy jest błyskawiczny. Skupimy się na tym, by po przypadkowym wyjściu z aplikacji i jej ponownym otwarciu, użytkownik lądował w tej samej kategorii.

## Plan Weryfikacji

### Testy Manualne
1. **Exit Test:** Na ekranie głównym kliknij raz "Wstecz". Sprawdź, czy pojawił się napis "Kliknij ponownie...". Kliknij szybko drugi raz i sprawdź, czy aplikacja się zamknęła.
2. **Tab Memory Test:** Przejdź do zakładki "Zapisane", zamknij aplikację (ubij proces) i otwórz ponownie. Sprawdź, czy sowa od razu pokazuje zakładkę "Zapisane".
3. **Detail Escape Test:** Będąc wewnątrz artykułu, kliknij "Wstecz". Sprawdź, czy wróciłeś do listy (standardowe zachowanie), a nie zamknąłeś aplikacji.
