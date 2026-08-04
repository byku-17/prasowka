# Plan Naprawy V6.1: Ujednolicenie Kategorii Miejskiej

Zgodnie z punktem 2 planu "Ostatniego Szlifu", zmieniamy systemową nazwę kategorii "Warszawa" na "Lokalne". Pozwoli to na zachowanie logicznej spójności interfejsu dla użytkowników z innych miast (np. Krakowa czy Wrocławia).

## Proposed Changes

### 1. Zmiana Nazwy w Modelu (NewsCategory)
Zmieniamy etykietę, która pojawia się w ustawieniach i systemie zarzadzania kategoriami.

#### [MODIFY] [news_category.dart](file:///D:/Apps/prasowka/lib/models/news_category.dart)
- Zmiana `name: 'Warszawa'` na `name: 'Lokalne'` dla kategorii o ID `warsaw`.
- **Dlaczego?** Nazwa "Lokalne" jest uniwersalna. W głównym menu (TabBar) nadal będzie wyświetlać się konkretne miasto (np. KRAKÓW), ale w "Zarządzaniu kategoriami" użytkownik zobaczy spójne "Lokalne".

### 2. Aktualizacja Listy Źródeł (NewsSource)
Upewnienie się, że nazwy domyślnych źródeł miejskich są czytelne.

#### [MODIFY] [news_source.dart](file:///D:/Apps/prasowka/lib/models/news_source.dart)
- Brak zmian funkcjonalnych, jedynie weryfikacja czy nazwy źródeł nie są sprzeczne z nową etykietą kategorii.

### 3. Weryfikacja UI
- Sprawdzenie `HomeScreen`: upewnienie się, że TabBar nadal poprawnie podmienia "Lokalne" na nazwę miasta (np. "POZNAŃ").
- Sprawdzenie `CategorySettingsPage`: weryfikacja czy na liście przełączników widnieje "Lokalne".

## Verification Plan

### Manual Verification
1.  **Hot Restart** aplikacji.
2.  Wejście w **Ustawienia -> Zarządzanie Kategoriami**.
3.  Sprawdzenie, czy kategoria o ikonie miasta nazywa się teraz **Lokalne** zamiast **Warszawa**.
4.  Powrót na ekran główny -> sprawdzenie czy na górnym pasku (TabBar) nadal widnieje nazwa wybranego miasta (np. KRAKÓW).
