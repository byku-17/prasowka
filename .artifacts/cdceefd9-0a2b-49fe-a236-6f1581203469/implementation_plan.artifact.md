# Plan Naprawy V7.8: Modernizacja DSL Kotlina (Final Build Fix)

Ten plan rozwiązuje błąd krytyczny kompilacji wynikający z użycia przestarzałego bloku `kotlinOptions` w najnowszej wersji Kotlina (2.2.20).

## Proposed Changes

### 1. Migracja na compilerOptions DSL (Root)
Kompilator Kotlina w wersji 2.x wymaga nowego sposobu definiowania parametrów JVM.

#### [MODIFY] [android/build.gradle.kts](file:///D:/Apps/prasowka/android/build.gradle.kts)
- Usunięcie bloku `kotlinOptions`.
- Implementacja bloku `compilerOptions` z jawnym użyciem stałej `JvmTarget.JVM_17`.

### 2. Synchronizacja w Module App
#### [MODIFY] [android/app/build.gradle.kts](file:///D:/Apps/prasowka/android/app/build.gradle.kts)
- Usunięcie bloku `kotlinOptions` z wewnątrz konfiguracji `android`.
- To ujednolici sposób budowania wszystkich części projektu.

## Verification Plan
1. Wykonanie `flutter clean`.
2. Uruchomienie budowania.
3. Potwierdzenie, że błąd `Using 'kotlinOptions... is an error` całkowicie ustąpił.
