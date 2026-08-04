# Plan Naprawy V6.2: Precyzyjny Wartownik Sportowy

Ten etap planu "Ostatniego Szlifu" skupia się na uszczelnieniu logiki powiadomień sportowych w tle, aby wyeliminować ryzyko otrzymywania alertów o meczach zaplanowanych na inne dni o tej samej godzinie.

## Proposed Changes

### 1. Weryfikacja Daty Meczu (BackgroundService)
Obecna logika sprawdza różnicę w minutach między aktualnym czasem a czasem rozpoczęcia meczu. Może to prowadzić do błędów, jeśli mecz o tej samej godzinie odbywa się jutro lub pojutrze.

#### [MODIFY] [background_service.dart](file:///D:/Apps/prasowka/lib/services/background_service.dart)
- **Dodanie sprawdzenia daty**: Zmiana warunku w pętli powiadomień sportowych.
- Nowy warunek: Powiadomienie zostanie wysłane tylko wtedy, gdy `mecz.rok == teraz.rok && mecz.miesiąc == teraz.miesiąc && mecz.dzień == teraz.dzień`.
- Dopiero po potwierdzeniu zbieżności daty, system sprawdzi różnicę minut (0-15 min przed startem).

### 2. Optymalizacja "Pined Matches"
Upewnienie się, że mechanizm Live Score (przypięte mecze) również respektuje datę, aby nie monitorować "duchów" z poprzednich kolejek.

## Verification Plan

### Manual Verification
1.  **Analiza Logiczna**: Sprawdzenie czy kod poprawnie porównuje komponenty daty (year, month, day).
2.  **Testowy Run**: Wysłanie testowego powiadomienia sportowego (Sowa pokaże w logach: `Sowa Wartownik: Data meczu zgadza się z dzisiejszą`).
