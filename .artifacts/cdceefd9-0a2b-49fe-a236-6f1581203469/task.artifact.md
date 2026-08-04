# Zadania: V7.7 Ostateczna Synchronizacja (Clean Build)

- [ ] Aktualizacja `android/app/build.gradle.kts`:
    - [ ] Przywrócenie `id("org.jetbrains.kotlin.android")` (bez wersji)
- [ ] Przebudowa `android/build.gradle.kts`:
    - [ ] Wyczyszczenie pliku do jednego bloku `subprojects`
    - [ ] Implementacja `afterEvaluate` z wymuszeniem Java 17 i `kotlinOptions`
- [ ] Procedura Clean Build (`flutter clean`)
- [ ] Weryfikacja kompilacji
- [ ] Commit i Push zmian
