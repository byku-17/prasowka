# Plan Naprawy V7.3: Stabilna Konfiguracja Gradle

Ten plan rozwiązuje błąd `Cannot run Project.afterEvaluate(Action) when the project is already evaluated` oraz ostatecznie synchronizuje wersję Java dla wszystkich modułów.

## Proposed Changes

### 1. Reorganizacja android/build.gradle.kts
Zmienimy sposób konfiguracji subprojektów na taki, który nie wymaga `afterEvaluate`, co wyeliminuje obecny błąd kompilacji.

#### [MODIFY] [android/build.gradle.kts](file:///D:/Apps/prasowka/android/build.gradle.kts)
- Usunięcie bloku `afterEvaluate`.
- Zastosowanie konfiguracji JVM bezpośrednio w `subprojects`.
- Usunięcie redundantnego bloku `subprojects { project.evaluationDependsOn(":app") }`, który prawdopodobnie powodował przedwczesną ewaluację modułów i wywoływał błąd.

### 2. Wymuszenie Java 17 przez Task Hooks
Użyjemy mechanizmu `tasks.withType`, który działa "leniwie" i zostanie zaaplikowany do wszystkich zadań, nawet jeśli wtyczki spróbują je zmienić później.

## Verification Plan

### Manual Verification
1.  **Wyczyszczenie**: `flutter clean`.
2.  **Kompilacja**: `flutter build apk` lub Debug.
3.  Jeśli aplikacja się uruchomi, oznacza to, że konfiguracja Gradle jest wreszcie poprawna i stabilna.
