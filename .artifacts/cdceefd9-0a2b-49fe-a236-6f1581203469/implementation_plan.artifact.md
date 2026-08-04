# Plan Naprawy V7.1: Rozwiązanie Konfliktu JVM (Dynamic Color Fix)

Ten plan ma na celu naprawę błędu kompilacji Androida, który pojawił się po dodaniu paczki `dynamic_color`. Błąd wynika z niezgodności wersji docelowej Java (JVM Target) pomiędzy kodem Java (1.8) a kodem Kotlin (17).

## Proposed Changes

### 1. Ujednolicenie wersji JVM (build.gradle.kts)
Wymusimy użycie Java 17 we wszystkich modułach (w tym w zewnętrznych wtyczkach takich jak `dynamic_color`).

#### [MODIFY] [android/app/build.gradle.kts](file:///D:/Apps/prasowka/android/app/build.gradle.kts)
- Upewnienie się, że `kotlinOptions` (starszy format) również wskazuje na JVM 17 wewnątrz bloku `android`.
- To najczęstsze rozwiązanie problemów z wtyczkami Fluttera, które nie wspierają jeszcze w pełni nowego bloku `kotlin { compilerOptions }`.

#### [MODIFY] [android/build.gradle.kts](file:///D:/Apps/prasowka/android/build.gradle.kts)
- Poprawa sposobu wymuszania wersji w `subprojects`. Zamiast stringa `"17"`, użyjemy stałej `JavaVersion.VERSION_17`, aby zapewnić pełną kompatybilność z Gradle.

### 2. Wyłączenie zbędnego "desugaringu" (opcjonalnie)
Jeśli Java 17 jest w pełni aktywna, sprawdzimy czy `isCoreLibraryDesugaringEnabled` nie powoduje konfliktów z nowszymi bibliotekami.

## Verification Plan

### Manual Verification
1.  **Wyczyszczenie projektu**: `flutter clean`.
2.  **Próba kompilacji**: `flutter build apk` lub uruchomienie w trybie Debug.
3.  Jeśli błąd zniknie, oznacza to, że wszystkie zadania kompilacji (Java i Kotlin) zostały pomyślnie zsynchronizowane do wersji 17.
