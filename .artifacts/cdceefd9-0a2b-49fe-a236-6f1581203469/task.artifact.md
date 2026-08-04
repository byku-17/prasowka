# Zadania: V7.4 Ostateczna Bitwa z JVM Target

- [ ] Aktualizacja `android/app/build.gradle.kts`:
    - [ ] Dodanie `id("org.jetbrains.kotlin.android")`
    - [ ] Dodanie `jvmToolchain(17)`
- [ ] Gruntowna przebudowa `android/build.gradle.kts`:
    - [ ] Usunięcie `evaluationDependsOn`
    - [ ] Implementacja `options.release.set(17)` dla zadań Java
- [ ] Weryfikacja kompilacji
