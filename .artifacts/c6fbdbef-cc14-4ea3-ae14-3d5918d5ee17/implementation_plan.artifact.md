# Plan: Nowa Tożsamość i Animowany Splash Screen

Celem jest ulepszenie ikony aplikacji oraz stworzenie zaawansowanego, animowanego ekranu startowego z efektem zderzenia tekstu "Pra" i "sówka".

## User Review Required

> [!IMPORTANT]
> **Ograniczenia Techniczne Splash Screena:** Systemowy ekran startowy (ten, który pojawia się natychmiast po kliknięciu ikony) jest statyczny. Twoja animacja "zderzenia" zostanie zaimplementowana jako pierwszy ekran wewnątrz Fluttera. Oznacza to, że najpierw zobaczysz tło, a ułamek sekundy później ruszy animacja.

> [!NOTE]
> **Efekt Zderzenia:** Do symulacji "kurzu" i "zderzenia kamieni" użyję tzw. *Particle System* zaimplementowanego w kodzie (CustomPainter), aby nie obciążać aplikacji ciężkimi plikami wideo.

## Proponowane Zmiany

### 1. Ikona Aplikacji (App Icon)
#### [MODIFY] [pubspec.yaml](file:///D:/Apps/prasowka/pubspec.yaml)
- Konfiguracja `adaptive_icon` dla Androida. Logo sowy zostanie wyśrodkowane i dopasowane do okręgu, unikając przycinania.

### 2. Animowany Ekran Startowy (Custom Splash)
#### [NEW] [splash_screen.dart](file:///D:/Apps/prasowka/lib/screens/splash_screen.dart)
Zaimplementuję ekran z następującą logiką:
- **Animacja:** Obrazek `Pra.png` wyjeżdża z lewej, `sówka.png` (lub `sówka 2.png`) z prawej.
- **Kolizja:** W momencie zetknięcia następuje "potrząśnięcie" ekranem (`Shake effect`) oraz przejście w pełne logo.
- **Efekty specjalne:** Wygenerowanie cząsteczek (kurz/odłamki) w miejscu zderzenia za pomocą `CustomPainter`.
- **Zasoby:** Wykorzystam dostarczone pliki `Pra.png`, `sówka.png` oraz `sówka 2.png`.

### 3. Integracja
#### [MODIFY] [main.dart](file:///D:/Apps/prasowka/lib/main.dart)
- Zmiana `home` na `SplashScreen`, który po zakończeniu animacji automatycznie przełączy się na `MainScreen`.

## Plan Weryfikacji

### Testy Manualne
1. **Ikona:** Sprawdzenie na liście aplikacji, czy sowa wypełnia okrąg i nie jest ucięta.
2. **Animacja:** Weryfikacja płynności zderzenia i czy efekt "kurzu" jest widoczny.
3. **Przejście:** Upewnienie się, że po animacji aplikacja przechodzi do newsów bez opóźnień.
