# Plan Naprawy V7.7: Ostateczna Synchronizacja JVM (Clean Build)

Ten plan ma na celu definitywne usunięcie błędu `Inconsistent JVM Target` poprzez ujednolicenie i uproszczenie konfiguracji budowania Androida.

## Proposed Changes

### 1. Gruntowne czyszczenie android/build.gradle.kts
Stworzymy jeden, spójny skrypt, który wymusi Java 17 we wszystkich modułach (w tym `dynamic_color`) po ich załadowaniu.

#### [MODIFY] [android/build.gradle.kts](file:///D:/Apps/prasowka/android/build.gradle.kts)
- Usunięcie wszystkich dotychczasowych bloków `subprojects`.
- Implementacja jednego bloku `subprojects` z `afterEvaluate`.
- **Wymuszenie Javy**: `sourceCompatibility = "17"` oraz `targetCompatibility = "17"`.
- **Wymuszenie Kotlina**: `jvmTarget = "17"` przy użyciu stabilnej składni `kotlinOptions`.

### 2. Korekta android/app/build.gradle.kts
Przywrócenie standardowej konfiguracji pluginów dla nowoczesnego Fluttera.

#### [MODIFY] [android/app/build.gradle.kts](file:///D:/Apps/prasowka/android/app/build.gradle.kts)
- Przywrócenie `id("org.jetbrains.kotlin.android")` w bloku `plugins` (bez wersji - wersja jest w `settings.gradle.kts`).
- Zachowanie parametrów `sourceCompatibility` i `targetCompatibility` na poziomie 17.

### 3. Procedura Clean Build
Wymusimy całkowite odświeżenie pamięci podręcznej Gradle, aby stare artefakty kompilacji (1.8) nie blokowały procesu.

## Verification Plan

### Manual Verification
1.  **Wyczyszczenie**: `flutter clean`.
2.  **Kompilacja**: `flutter build apk` lub Debug.
3.  Jeśli błąd `Inconsistent JVM Target` zniknie, oznacza to, że `dynamic_color` został pomyślnie zmuszony do pracy w standardzie Java 17.
