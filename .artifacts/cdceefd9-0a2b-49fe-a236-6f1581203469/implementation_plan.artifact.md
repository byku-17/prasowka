# Plan Naprawy V7.4: Ostateczna Bitwa z JVM Target

Ten plan ma na celu usunięcie błędów w konfiguracji Gradle, które uniemożliwiały poprawne wymuszenie wersji Java 17 na wszystkich modułach aplikacji.

## Proposed Changes

### 1. Naprawa struktury android/build.gradle.kts
Usunięcie błędnych zależności i ujednolicenie konfiguracji wszystkich modułów.

#### [MODIFY] [android/build.gradle.kts](file:///D:/Apps/prasowka/android/build.gradle.kts)
- **Usunięcie `evaluationDependsOn(":app")`**: To wyeliminuje błąd `Project already evaluated`.
- **Zastosowanie `options.release`**: Wymuszenie wersji 17 dla `JavaCompile` przy użyciu najsilniejszego dostępnego mechanizmu.
- **Ujednolicenie Kotlina**: Wymuszenie `jvmTarget = 17` dla wszystkich zadań kompilacji Kotlina w projekcie.

### 2. Aktualizacja android/app/build.gradle.kts
Dostosowanie aplikacji głównej do najnowszych standardów zarządzania Kotlinem.

#### [MODIFY] [android/app/build.gradle.kts](file:///D:/Apps/prasowka/android/app/build.gradle.kts)
- **Dodanie pluginu Kotlina**: Jawne zadeklarowanie `id("org.jetbrains.kotlin.android")`.
- **Wymuszenie Toolchaina**: Użycie `jvmToolchain(17)` – nowoczesnego sposobu na zapewnienie, że cały moduł używa poprawnej wersji JDK.

### 3. Czyszczenie i synchronizacja
- Usunięcie niepotrzebnych, zduplikowanych bloków `subprojects`.

## Verification Plan
1. Wykonanie `flutter clean`.
2. Uruchomienie budowania: `flutter build apk` (lub tryb Debug).
3. Sprawdzenie czy błąd `Inconsistent JVM-target` dla wtyczki `dynamic_color` definitywnie zniknął.
