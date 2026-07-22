# Zadania: Ekstremalna Optymalizacja Wydajności

- [ ] Rozbudowa `StorageService` o obsługę cache'u artykułów
- [ ] Refaktoryzacja `RssService`:
    - [ ] Przeniesienie parsowania do Isolate (`compute`)
    - [ ] Dodanie obsługi błędów i timeoutów na poziomie pojedynczego źródła
- [ ] Optymalizacja `NewsProvider`:
    - [ ] Logika "Cache-First" (natychmiastowe ładowanie z dysku)
    - [ ] Pobieranie w tle w paczkach (batching)
    - [ ] Zarządzanie flagą `isBackgroundLoading`
- [ ] Aktualizacja `HomeScreen`:
    - [ ] Subtelny wskaźnik ładowania pod AppBar
    - [ ] Płynne odświeżanie listy bez "skakania" obrazu
- [ ] Czyszczenie starych danych w Hive (retencja 3 dni)
