# Zadania: V7.3 Stabilizacja Gradle

- [x] Aktualizacja `android/build.gradle.kts`:
    - [x] Usunięcie problematycznego bloku `afterEvaluate`
    - [x] Usunięcie `evaluationDependsOn(":app")` powodującego przedwczesną ocenę
    - [x] Zastosowanie bezpiecznej konfiguracji `configureEach`
- [ ] Weryfikacja kompilacji (`flutter build apk` lub Debug)
- [ ] Commit i Push zmian
