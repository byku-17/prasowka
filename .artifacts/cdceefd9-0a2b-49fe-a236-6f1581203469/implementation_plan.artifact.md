# Plan Naprawy V7.2: Ostateczna Synchronizacja JVM i KGP

Ten plan ma na celu rozwiązanie uporczywego błędu "Inconsistent JVM Target" oraz wyeliminowanie ostrzeżeń dotyczących Kotlin Gradle Plugin (KGP), które mogą blokować przyszłe wersje aplikacji.

## Proposed Changes

### 1. Agresywna Synchronizacja JVM (android/build.gradle.kts)
Użyjemy mechanizmu `afterEvaluate`, aby upewnić się, że nasze ustawienia (Java 17) nie zostaną nadpisane przez domyślne konfiguracje wtyczek.

#### [MODIFY] [android/build.gradle.kts](file:///D:/Apps/prasowka/android/build.gradle.kts)
- Zastosowanie `tasks.withType<JavaCompile>` wewnątrz `subprojects` z jawnym przypisaniem wersji `"17"`.
- Zastosowanie `tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>` z jawnym ustawieniem `jvmTarget = "17"`.
- Wykorzystanie `afterEvaluate`, aby wymusić te parametry po tym, jak wtyczki skończą swoją własną konfigurację.

### 2. Rozwiązanie ostrzeżenia o Built-in Kotlin
Flutter migruje na model, w którym wersja Kotlina jest zarządzana centralnie. Ostrzeżenie sugeruje, że niektóre wtyczki nakładają własny KGP.

#### [MODIFY] [android/settings.gradle.kts](file:///D:/Apps/prasowka/android/settings.gradle.kts)
- Weryfikacja czy wersje wtyczek w bloku `plugins` są zgodne z zaleceniami dla nowej wersji Fluttera.

### 3. Aktualizacja Wtyczek (pubspec.yaml)
Podniesiemy wersje krytycznych wtyczek, aby wspierały najnowsze standardy kompilacji.

#### [MODIFY] [pubspec.yaml](file:///D:/Apps/prasowka/pubspec.yaml)
- `workmanager: ^0.9.0+3` -> `0.9.3`
- `share_plus: ^9.0.0` -> `10.0.2`
- `package_info_plus: ^8.0.0` (jeśli istnieje)

## Verification Plan

### Manual Verification
1.  **Wyczyszczenie**: `flutter clean`.
2.  **Kompilacja**: `flutter build apk` lub uruchomienie w trybie Debug.
3.  **Weryfikacja logów**: Sprawdzenie czy ostrzeżenia o KGP zniknęły i czy błąd "Inconsistent JVM Target" przestał występować.
