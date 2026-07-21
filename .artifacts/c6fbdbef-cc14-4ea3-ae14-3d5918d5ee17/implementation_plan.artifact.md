# Plan Poprawy Stabilności i Optymalizacji (Hardening)

Celem jest uodpornienie aplikacji na błędy sieciowe, wyścigi stanów oraz nieprzewidziane formaty danych z kanałów RSS.

## User Review Required

> [!IMPORTANT]
> Dodanie timeoutów (10 sekund) sprawi, że aplikacja nie będzie "wisieć" na ekranie ładowania przy bardzo wolnym połączeniu, ale wyświetli błąd. Jest to pożądane zachowanie dla UX.

## Proponowane Zmiany

### Logika Biznesowa (Services)

#### [MODIFY] [rss_service.dart](file:///D:/Apps/prasowka/lib/services/rss_service.dart)
- Dodanie `timeout` do zapytań HTTP.
- Rozszerzenie `_extractImageUrl` o obsługę tagów `<media:thumbnail>` i `<atom:link>`.
- Ulepszenie `_parseRssDate` o dodatkowe formaty i `trim()`.

#### [MODIFY] [storage_service.dart](file:///D:/Apps/prasowka/lib/services/storage_service.dart)
- Dodanie sprawdzenia `Hive.isBoxOpen`, aby uniknąć błędów przy wielokrotnej inicjalizacji.

### Zarządzanie Stanem (Providers)

#### [MODIFY] [news_provider.dart](file:///D:/Apps/prasowka/lib/providers/news_provider.dart)
- Wprowadzenie `_lastRequestedCategoryId`. Jeśli dane z RSS wrócą, gdy użytkownik już zdążył zmienić kategorię na inną, wynik zostanie odrzucony (zapobieganie "miganiu" starej treści).
- Obsługa błędów sieciowych (`SocketException`) z przyjaznym komunikatem.

### Warstwa Prezentacji (UI)

#### [MODIFY] [article_detail_screen.dart](file:///D:/Apps/prasowka/lib/screens/article_detail_screen.dart)
- Poprawa czytelności: dodanie placeholderów dla brakującej treści i ulepszenie formatowania daty.

## Plan Weryfikacji

### Testy Manualne
1. **Test Wyścigu:** Szybkie klikanie w 3 różne kategorie pod rząd. Weryfikacja, czy finalnie wyświetlona lista odpowiada ostatniej klikniętej kategorii.
2. **Test Offline:** Wyłączenie Wi-Fi i próba odświeżenia. Sprawdzenie, czy pojawia się komunikat o braku połączenia.
3. **Test RSS Edge Cases:** Sprawdzenie, czy artykuły bez zdjęć nadal wyświetlają się poprawnie (bez pustych szarych bloków).
