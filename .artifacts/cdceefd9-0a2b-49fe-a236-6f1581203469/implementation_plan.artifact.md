# Plan Naprawy V7.5: Kompatybilna Synchronizacja JVM

Ten plan naprawia błąd `Using '--release' option for JavaCompile is not supported` oraz ostatecznie rozwiązuje konflikt wersji Java 1.8 vs 17 w modułach zewnętrznych (np. `dynamic_color`, `audio_session`).

## Proposed Changes

### 1. Naprawa android/build.gradle.kts (Root)
Uprościmy skrypt, usuwając błędne zależności i zastępując niekompatybilną opcję `--release` standardowymi ustawieniami kompatybilności.

#### [MODIFY] [android/build.gradle.kts](file:///D:/Apps/prasowka/android/build.gradle.kts)
- **Usunięcie `options.release`**: Ta opcja koliduje z procesem budowania Androida (AGP), co powodowało błąd w projekcie `:audio_session`.
- **Usunięcie `evaluationDependsOn(":app")`**: To wyeliminuje błąd `Project already evaluated`, pozwalając na poprawne użycie bloku `afterEvaluate`.
- **Wymuszenie Java 17 przez `afterEvaluate`**: Użyjemy bezpiecznego mechanizmu, który nadpisze ustawienia wtyczek (np. `dynamic_color`) po ich załadowaniu, wymuszając wersję 17 dla zadań Java i Kotlin.

### 2. Stabilizacja android/app/build.gradle.kts
- Upewnienie się, że główna aplikacja pozostaje przy `jvmToolchain(17)`, co jest najstabilniejszą formą dla nowych wersji Fluttera.

## Verification Plan

### Manual Verification
1.  **Wyczyszczenie**: `flutter clean`.
2.  **Kompilacja**: `flutter build apk` lub Debug.
3.  **Weryfikacja**: Brak błędu `--release` oraz brak błędu `Inconsistent JVM-target`.
