# Plan Naprawy V7.9: Definitywna Synchronizacja i Migracja Built-in Kotlin

Ten plan rozwiązuje błąd `Inconsistent JVM Target` oraz usuwa ostrzeżenia o niekompatybilności z przyszłymi wersjami Fluttera poprzez pełną migrację na nowoczesny model zarządzania Kotlinem.

## Proposed Changes

### 1. Migracja na Built-in Kotlin (android/app/build.gradle.kts)
Usunięcie ręcznego stosowania pluginu Kotlina, co pozwoli Flutterowi na przejęcie kontroli nad wersjami (zgodnie z zaleceniami Flutter 3.24+).

#### [MODIFY] [android/app/build.gradle.kts](file:///D:/Apps/prasowka/android/app/build.gradle.kts)
- **Usunięcie `id("org.jetbrains.kotlin.android")`** z bloku `plugins`.
- **Usunięcie bloku `kotlinOptions`** (przestarzały DSL).
- Zachowanie `compileOptions` ustawionych na 17.

### 2. Gruntowna przebudowa android/build.gradle.kts (Root)
Uproszczenie skryptu i usunięcie blokad, które uniemożliwiały poprawne ustawienie wersji Java 17 we wtyczkach.

#### [MODIFY] [android/build.gradle.kts](file:///D:/Apps/prasowka/android/build.gradle.kts)
- **Usunięcie `evaluationDependsOn(":app")`**: To kluczowy krok — ta linia powodowała, że wtyczki były oceniane zbyt wcześnie, przez co nie mogliśmy zmienić ich wersji Java.
- **Usunięcie `afterEvaluate`**: Zastąpienie go bezpośrednią konfiguracją `tasks.withType`.
- **Wymuszenie wersji 17**: Zapewnienie, że `JavaCompile` i `KotlinCompile` we wszystkich modułach (w tym `dynamic_color`) używają JVM 17.

### 3. Procedura Clean Build
Wymuszenie na Gradle odświeżenia wszystkich artefaktów.

## Verification Plan
1. Wykonanie `flutter clean`.
2. Uruchomienie `flutter build apk` lub Debug.
3. Potwierdzenie braku ostrzeżeń o KGP oraz błędu `Inconsistent JVM Target`.
