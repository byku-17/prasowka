# Plan Naprawy V7.6: Migracja na Built-in Kotlin i Fix JDK 17

Ten plan rozwiązuje błąd braku instalacji Java 17 (`jvmToolchain`) oraz migruje aplikację na nowy model zarządzania Kotlinem ("Built-in Kotlin"), co eliminuje ostrzeżenia Fluttera.

## Proposed Changes

### 1. Rezygnacja z rygorystycznego jvmToolchain
Błąd `Cannot find a Java installation` wynika z użycia `jvmToolchain(17)`, który wymaga od Gradle precyzyjnego odnalezienia lub pobrania JDK 17. Zamiast tego zaufamy środowisku Fluttera, które zazwyczaj ma już skonfigurowaną odpowiednią wersję Java.

#### [MODIFY] [android/app/build.gradle.kts](file:///D:/Apps/prasowka/android/app/build.gradle.kts)
- Usunięcie bloku `kotlin { jvmToolchain(17) }`.
- Zachowanie `compileOptions` i `kotlinOptions` ustawionych na 17 dla zachowania kompatybilności.

### 2. Migracja na Built-in Kotlin
Zgodnie z zaleceniami Fluttera 3.24+, usuniemy ręczne nakładanie pluginu Kotlina, aby uniknąć konfliktów w przyszłych wersjach.

#### [MODIFY] [android/app/build.gradle.kts](file:///D:/Apps/prasowka/android/app/build.gradle.kts)
- Usunięcie `id("org.jetbrains.kotlin.android")` z bloku `plugins`. Flutter załaduje go automatycznie.

#### [MODIFY] [android/settings.gradle.kts](file:///D:/Apps/prasowka/android/settings.gradle.kts)
- Upewnienie się, że plugin Kotlina jest zdefiniowany poprawnie dla mechanizmu `flutter-plugin-loader`.

### 3. Stabilizacja subprojektów
#### [MODIFY] [android/build.gradle.kts](file:///D:/Apps/prasowka/android/build.gradle.kts)
- Uproszczenie bloku `subprojects` — pozostawienie tylko niezbędnych override'ów dla `JavaCompile` i `KotlinCompile`, aby wtyczki (np. `dynamic_color`) przestały zgłaszać błędy niespójności.

## Verification Plan

### Manual Verification
1.  **Wyczyszczenie**: `flutter clean`.
2.  **Kompilacja**: `flutter build apk` lub Debug.
3.  **Weryfikacja**: Brak błędu o braku Java 17 oraz brak ostrzeżeń o Kotlin Gradle Plugin (KGP).
