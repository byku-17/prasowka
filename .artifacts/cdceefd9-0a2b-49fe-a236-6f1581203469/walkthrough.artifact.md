# Walkthrough V7.11: Upgrade pluginów + Ujednolicone motywy

## Zrealizowane zmiany:

### 1. Upgrade 13 pluginów do Built-in Kotlin
Zaktualizowano pluginy do wersji kompatybilnych z Built-in Kotlin (Flutter 3.22+). Kluczowe zmiany:
- `flutter_local_notifications` ^17.2.4 → ^22.2.0 (breaking API: named params)
- `workmanager` ^0.9.3 → ^0.10.7
- `share_plus` ^10.0.2 → ^13.3.0
- `desugar_jdk_libs` 2.0.3 → 2.1.4

### 2. Fix breaking API flutter_local_notifications 22.x
Naprawiono 5 wywołań `show()` i 1 `initialize()` — przejście z positional na named parameters.

### 3. Build system: Java 21
- `android/app/build.gradle.kts`: Java 17 → 21 (domyślny target Built-in Kotlin)
- `android/build.gradle.kts`: usunięto agresywny blok subprojects (Flutter zarządza JVM samodzielnie)

### 4. Rozjaśniony Royal Purple
- `royalPurple`: #905CFF → **#B47AFF** (jaśniejszy, pastelowy)
- Nowe kolory: `royalPurpleDark` #8B5CF6, `lightPurple` #E8DAFF
- Dark bg: #130E26 → #1A1528 (rozjaśniony)
- Light scaffold: #FBFBFF → #F8F5FF (lekko fioletowe)

### 5. Ujednolicone ustawienia motywu
- Usunięto duplikaty: "Tryb jasny/ciemny" + "Kolorystyka aplikacji"
- Jedno menu z 4 opcjami: **Jasny / Medium (fioletowy) / Ciemny / Systemowy**
- Bottom sheet z ikonami i check mark

## Jak zweryfikować?

1. `flutter clean && flutter pub get`
2. `flutter build apk --debug` — powinien przejść bez błędów
3. Sprawdź ustawienia → Wygląd → 4 opcje motywu
4. Przełącz między motywami i zweryfikuj kolory

> [!NOTE]
> Pozostałe 2 ostrzeżenia KGP (dynamic_color, workmanager_android) to przyszłe wymagania Flutter — nie blokują buildu.
