# Plan: Eliminacja napisu "Brak treści" i optymalizacja płynności

Celem jest usunięcie irytującego migania komunikatu "Brak treści" podczas ładowania oraz dalsze zwiększenie płynności interfejsu.

## User Review Required

> [!IMPORTANT]
> **Koniec z miganiem:** Zmienimy logikę widoku tak, aby komunikat "Brak treści" pojawiał się **wyłącznie jako ostateczność**, gdy sowa na 100% potwierdzi, że internet jest pusty. W każdym innym przypadku ładowania (nawet po przełączeniu zakładki) zobaczysz profesjonalny efekt Shimmer.
> **Persistence:** Upewnimy się, że stan "pierwszego ładowania" jest poprawnie zarządzany, aby sowa nie "zapominała", że już wcześniej coś pobrała.

## Proponowane Zmiany

### 1. Naprawa logiki widoku (UI Logic)

#### [MODIFY] [widgets/category_news_list.dart](file:///D:/Apps/prasowka/lib/widgets/category_news_list.dart)
- Zmiana kolejności sprawdzania stanów:
    1. Jeśli są artykuły -> Pokaż listę.
    2. Jeśli sowa pracuje (`isLoading`) -> **Zawsze** pokaż Shimmer (zamiast "Brak treści").
    3. Jeśli sowa skończyła i nic nie ma -> Pokaż "Brak treści".

### 2. Optymalizacja startu i sesji (NewsProvider)

#### [MODIFY] [providers/news_provider.dart](file:///D:/Apps/prasowka/lib/providers/news_provider.dart)
- Ustawienie `_hasEverLoadedMap` na `true` również w przypadku błędów, aby uniknąć nieskończonego Shimmera.
- Przyspieszenie pierwszego wejścia do kategorii poprzez natychmiastowe ładowanie z cache bez oczekiwania na asynchroniczne operacje Hive, jeśli to możliwe.

### 3. "Lekkie" karty i reakcje (ArticleCard)

#### [MODIFY] [widgets/article_card.dart](file:///D:/Apps/prasowka/lib/widgets/article_card.dart)
- Dalsze uproszczenie struktury reakcji.
- Usunięcie zbędnych warstw `Material` i `InkWell` tam, gdzie wystarczy prosty `GestureDetector`, co odciąży procesor graficzny Twojego Samsunga.

## Plan Weryfikacji

### Testy wizualne
1. **Switch Test:** Szybkie przełączanie między kategoriami (Biznes -> Sport -> Biznes). Oczekujemy: Shimmer lub artykuły, **brak** napisu "Brak treści" w trakcie ładowania.
2. **First Run Test:** Wyczyszczenie cache i start. Oczekujemy: Shimmer przechodzący płynnie w newsy.

### Testy wydajności
1. **Samsung A52 Check:** Przewijanie długiej listy (50+ newsów) z włączonymi zdjęciami. Oczekujemy: stałe 60 FPS bez szarpnięć.
