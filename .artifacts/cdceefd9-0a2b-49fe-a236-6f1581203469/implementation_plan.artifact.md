# Plan Naprawy V7.10: Ostateczne Rozwiązanie JVM Target

Ten plan ma na celu definitywne usunięcie błędu `Inconsistent JVM Target` oraz wyczyszczenie drobnych ostrzeżeń z analizatora kodu.

## Proposed Changes

### 1. Cleanup kodu (BackgroundService)
Usunięcie nieużywanego importu, który zgłasza ostrzeżenie w `flutter analyze`.

#### [MODIFY] [background_service.dart](file:///D:/Apps/prasowka/lib/services/background_service.dart)
- Usunięcie linii `import 'package:url_launcher/url_launcher.dart';`.

### 2. Agresywne wymuszenie JVM 17 (android/build.gradle.kts)
Użyjemy najbardziej rygorystycznego sposobu konfiguracji zadań, aby nadpisać hardkodowane ustawienia we wtyczkach.

#### [MODIFY] [android/build.gradle.kts](file:///D:/Apps/prasowka/android/build.gradle.kts)
- Ujednolicenie wszystkich bloków `subprojects`.
- Zastosowanie `tasks.withType<JavaCompile>().configureEach` z jawnym ustawieniem `sourceCompatibility = "17"` oraz `targetCompatibility = "17"`.
- Zastosowanie `tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach` z jawnym ustawieniem `jvmTarget = "17"` przez `compilerOptions`.

### 3. Aktualizacja Wersji UI
#### [MODIFY] [settings_screen.dart](file:///D:/Apps/prasowka/lib/screens/settings_screen.dart)
- Zmiana wersji na `1.5.2 (V7.10 Final Build)`.

## Verification Plan
1. Wykonanie **`flutter clean`**.
2. Uruchomienie budowania w trybie Debug.
3. Sprawdzenie czy błąd `Inconsistent JVM Target` oraz ostrzeżenie o `url_launcher` zniknęły.
