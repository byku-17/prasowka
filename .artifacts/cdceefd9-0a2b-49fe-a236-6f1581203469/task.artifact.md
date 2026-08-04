# Zadania: V7.6 Migracja na Built-in Kotlin i Fix JDK 17

- [ ] Aktualizacja `android/app/build.gradle.kts`:
    - [ ] Usunięcie `id("org.jetbrains.kotlin.android")` (migracja na Built-in Kotlin)
    - [ ] Usunięcie bloku `kotlin { jvmToolchain(17) }`
- [ ] Aktualizacja `android/build.gradle.kts`:
    - [ ] Uproszczenie wymuszania wersji Java 17 w subprojektach (bez `afterEvaluate` jeśli możliwe lub w bezpieczniejszy sposób)
- [ ] Weryfikacja kompilacji
- [ ] Commit i Push zmian
