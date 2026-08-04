# Implementation Plan V7.11: Upgrade pluginów + Motywy

## Status: ZAKOŃCZONE ✅

## Zmiany w V7.11

### 1. Upgrade pluginów do Built-in Kotlin
Zaktualizowano 13 pluginów do wersji wspierających Built-in Kotlin (Flutter 3.22+):

| Plugin | Przed | Po |
|---|---|---|
| flutter_local_notifications | ^17.2.4 | ^22.2.0 |
| workmanager | ^0.9.3 | ^0.10.7 |
| share_plus | ^10.0.2 | ^13.3.0 |
| google_fonts | ^6.2.1 | ^6.3.3 |
| cached_network_image | ^3.3.1 | ^3.4.1 |
| flutter_widget_from_html | ^0.15.1 | ^0.15.3 |
| package_info_plus | 9.0.1 | ^10.2.1 |
| wakelock_plus | 1.5.2 | ^1.7.0 |
| flutter_launcher_icons | ^0.13.1 | ^0.14.4 |
| build_runner | ^2.4.9 | ^2.4.13 |
| flutter_lints | ^3.0.0 | ^3.0.2 |
| flutter_dotenv | ^5.1.0 | ^5.2.1 |
| desugar_jdk_libs | 2.0.3 | 2.1.4 |

#### [MODIFY] [pubspec.yaml](file:///D:/Apps/prasowka/pubspec.yaml)
- Aktualizacja wersji wszystkich powyższych pluginów.

#### [MODIFY] [android/app/build.gradle.kts](file:///D:/Apps/prasowka/android/app/build.gradle.kts)
- Java 17 → Java 21 (domyślny JVM target Built-in Kotlin)
- desugar_jdk_libs 2.0.3 → 2.1.4

#### [MODIFY] [android/build.gradle.kts](file:///D:/Apps/prasowka/android/build.gradle.kts)
- Usunięcie agresywnego bloku subprojects wymuszającego JVM 17 na wszystkich modułach.

### 2. Fix breaking API flutter_local_notifications 22.x
#### [MODIFY] [background_service.dart](file:///D:/Apps/prasowka/lib/services/background_service.dart)
- 5 wywołań `show()`: positional → named parameters (id, title, body, notificationDetails, payload)
- `initialize()`: named parameter `settings:` zamiast positional

### 3. Rozjaśnienie Royal Purple
#### [MODIFY] [app_theme.dart](file:///D:/Apps/prasowka/lib/theme/app_theme.dart)
- royalPurple: #905CFF → #B47AFF
- Nowe: royalPurpleDark #8B5CF6, lightPurple #E8DAFF
- Royal Dark: midnightPurple #130E26 → #1A1528, royalDarkSurface #241D36
- Royal Light: scaffold #FBFBFF → #F8F5FF, cardTheme z fioletowym borderem

### 4. Ujednolicenie ustawień motywu
#### [MODIFY] [appearance_settings_page.dart](file:///D:/Apps/prasowka/lib/screens/appearance_settings_page.dart)
- Usunięto duplikaty: "Tryb jasny/ciemny" + "Kolorystyka aplikacji"
- Jedno menu z 4 opcjami: Jasny / Medium (fioletowy) / Ciemny / Systemowy
- Usunięto _ThemeVariantTile (pozioma lista kolorów)
- Nowy _buildUnifiedThemePicker z bottom sheet

#### [MODIFY] [settings_provider.dart](file:///D:/Apps/prasowka/lib/providers/settings_provider.dart)
- AppThemeVariant.medium → _buildRoyalLightTheme() (medium = jasny fiolet)

## Verification
1. `flutter pub get` — OK
2. `flutter analyze` — 0 errors (6 info warnings — pre-existing)
3. `flutter build apk --debug` — OK
4. Wszystkie motywy działają: Jasny, Medium (fioletowy), Ciemny, Systemowy

## Przyszły plan: V7.12 "Mniej klików, więcej treści"
Zobacz task.artifact.md — Faza 1-4 (Dashboard, Swipe, Presety, Polish)
