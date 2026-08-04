# Zadania: V7.5 Kompatybilna Synchronizacja JVM

- [ ] Aktualizacja `android/build.gradle.kts`:
    - [ ] Usunięcie `options.release.set(17)` (niekompatybilne z AGP)
    - [ ] Zastosowanie `afterEvaluate` z `sourceCompatibility` i `targetCompatibility`
    - [ ] Wymuszenie JVM 17 dla Kotlina
- [ ] Weryfikacja kompilacji
- [ ] Commit i Push zmian
