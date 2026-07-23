# Plan: Turbo Sowa v4 - Eliminacja "Zadyszki" i Pustych Ekranów

Zdiagnozowałem przyczynę spowolnienia: sowa była zbyt „ambitna” i dla każdego portalu (nawet małego) tworzyła oddzielny proces w procesorze (Isolate). Przy 30-130 źródłach to powodowało „korek” w pamięci telefonu i lagowanie. Dodatkowo, błędy w zarządzaniu stanem sprawiały, że widziałeś „Brak treści” zbyt często.

## User Review Required

> [!IMPORTANT]
> **Lżejsze Parsowanie:** Zrezygnujemy z tworzenia osobnych procesów dla każdego newsa. Sowa będzie teraz przetwarzać dane bezpośrednio w "głównym nurcie", co przy obecnej optymalizacji kodu będzie znacznie szybsze i nie obciąży tak bardzo baterii.
> **Natychmiastowy Shimmer:** Poprawimy kolejność komend, aby po kliknięciu zakładki Shimmer (pulsujące karty) pojawiał się w ułamku sekundy, eliminując napis "Brak treści".

## Proponowane Zmiany

### 1. Odchudzenie Silnika (Services)

#### [MODIFY] [rss_service.dart](file:///D:/Apps/prasowka/lib/services/rss_service.dart)
- Usunięcie funkcji `compute` z pobierania pojedynczych artykułów.
- Przeniesienie dekodowania tekstu do głównego wątku (optymalizacja dla małych paczek danych).
- Wzmocnienie obsługi błędów sieciowych, aby jeden zablokowany portal nie spowalniał całej reszty.

### 2. Stabilizacja Widoku (UI Logic)

#### [MODIFY] [news_provider.dart](file:///D:/Apps/prasowka/lib/providers/news_provider.dart)
- Wymuszenie stanu `isLoading = true` natychmiast po wywołaniu `fetchNews`.
- Poprawa zapisu flagi `hasEverLoaded` — sowa zapamięta, że już próbowała pobrać dane, nawet jeśli wystąpił błąd, co zapobiegnie "miganiu" interfejsu.

#### [MODIFY] [widgets/category_news_list.dart](file:///D:/Apps/prasowka/lib/widgets/category_news_list.dart)
- Uproszczenie warunków wyświetlania: Shimmer ma najwyższy priorytet podczas ładowania pierwszej porcji danych.

### 3. Optymalizacja Przewijania (Performance)

#### [MODIFY] [widgets/article_card.dart](file:///D:/Apps/prasowka/lib/widgets/article_card.dart)
- Dalsze uproszczenie renderowania cieni i zaokrągleń (wykorzystanie stałych wartości).

## Plan Weryfikacji

### Testy Wydajności
1. **Samsung A52 Stress Test:** Szybkie przełączanie między 5 zakładkami pod rząd. Oczekujemy: płynne animacje Shimmera, brak czarnych ekranów i brak komunikatu "Brak treści" przed załadowaniem.
2. **Batch Test:** Sprawdzenie, czy newsy pojawiają się w grupach bez "zamrażania" przewijania.

### Testy Stabilności
1. **Offline Test:** Wyłączenie internetu i sprawdzenie, czy sowa wyświetla "Brak treści" z poprawnym logiem technicznym dopiero po zakończeniu próby połączenia.
