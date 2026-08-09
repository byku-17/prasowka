# Plan na jutro — ustawienia (rozbudowa)

## ✅ Już mamy (przegląd gotowych elementów)
- [x] Główny przełącznik powiadomień (= Wartownik Sowy, włącz/wyłącz + rejestracja taska)
- [x] Powiadomienia sportowe jako osobny kanał (`sowa_sport`): gol, LIVE, start meczu (dla przypiętych/faworytów)
- [x] Rozmiar czcionki w czytniku (przycisk „+/–" w detail: 14/16/18) — brak ustawienia centralnego
- [x] Otwieranie artykułów w aplikacji (WebView) + przycisk „otwórz w przeglądarce" (`launchUrl`)
- [x] Sortowanie: nieprzeczytane najpierw, obrazki najpierw, najnowsze najpierw (hardcoded)
- [x] Ostatnia synchronizacja widoczna w KONTO (`sync.lastSync`)
- [x] Synchronizacja pełnego zakresu: ustawienia, tagi, artykuły, zainteresowania, kategorie, źródła, historia czytania, przypięte mecze
- [x] Zakończone i nadchodzące mecze pokazywane na pasku (finished z TTL 12h) — bez przełączników

## 🚧 Nowe funkcje (do zrobienia)

### WYGLĄD (~14h)
- [x] Rozmiar tekstu artykułów (mały/standardowy/duży) — UI w Ustawieniach (~1h)
- [ ] Krój czcionki (~3h)
- [x] Sposób otwierania artykułów: w aplikacji / zewnętrzna przeglądarka (~1h)
- [ ] Układ listy artykułów: kompaktowy / wygodny (~4h)
- [ ] Wyświetlanie obrazków: zawsze / tylko Wi-Fi / nigdy (~5h)

### POWIADOMIENIA (~12h)
- [ ] Godziny działania (np. 7:00–21:00) (~3h)
- [ ] Częstotliwość sprawdzania: co godzinę / co 3 godziny / raz dziennie (~3h)
- [ ] Rodzaje alertów: nowe artykuły / ważne wiadomości / podsumowanie (~4h)
- [ ] Przełącznik powiadomień sportowych osobno od paska wyników (~2h)

### TREŚCI (~21h)
- [ ] Częstotliwość odświeżania: ręcznie / co godzinę / co 6 godzin (~4h)
- [ ] Odświeżanie tylko przez Wi-Fi (~3h)
- [ ] Usuwanie starych artykułów: po 7 / 14 / 30 dniach (~3h)
- [ ] Domyślna kolejność artykułów: najnowsze / nieprzeczytane / popularne (~3h)
- [ ] Słowa wykluczające (filtrowanie artykułów) (~3h)
- [ ] Domyślne zachowanie tagów (auto-przypisywanie) (~5h)

### SPORT (~9h)
- [ ] Kolejność drużyn i lig (~3h)
- [x] Pokazuj wyniki zakończonych spotkań (przełącznik) (~2h)
- [x] Pokazuj nadchodzące mecze (przełącznik) (~2h)
- [x] Powiadomienia o wyniku (przełącznik) (~1h)
- [x] Powiadomienia o rozpoczęciu meczu (przełącznik) (~1h)

### DANE I NARZĘDZIA (~13h)
- [ ] Co synchronizować: wybór zakresu (źródła, kategorie, zainteresowania, tagi, przeczytane, ustawienia) (~4h)
- [ ] Automatyczna synchronizacja włącz/wyłącz (~5h)
- [x] Resetuj ustawienia aplikacji (~2h)
- [x] Usuń lokalne dane (~2h)

## Sugerowana kolejność (najwyższy stosunek wartości do czasu)
1. Rozmiar tekstu (1h), sposób otwierania (1h), przełączniki sportowe (4h), reset/usuń dane (4h), godziny działania (3h) — razem ~13h
2. Potem: częstotliwość odświeżania, kolejność artykułów, słowa wykluczające
3. Na końcu (najcięższe): układ listy, obrazki Wi-Fi, auto-tagi, automatyczna synchronizacja
