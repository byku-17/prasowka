# Plan Rozwoju V5.4: Inteligentna Gazeta

Ten etap ma na celu poprawę czytelności listy newsów oraz lepszą ekspozycję treści dopasowanych do zainteresowań użytkownika.

## User Review Required

> [!NOTE]
> Zmiana wizualna: Artykuły oznaczone jako "przeczytane" będą teraz znacznie mocniej odróżniać się od nowych treści (przyciemnienie całego kafelka).

## Proposed Changes

### 1. Wizualny Status "Przeczytane" (ArticleCard)
Poprawimy widoczność artykułów, które użytkownik już odwiedził, aby ułatwić skanowanie listy w poszukiwaniu nowości.

#### [MODIFY] [article_card.dart](file:///D:/Apps/prasowka/lib/widgets/article_card.dart)
- **Przyciemnienie obrazka**: Dodanie `ColorFiltered` lub nakładki półprzezroczystej na zdjęcie, gdy `isRead == true`.
- **Wygaszenie opisu**: Zmniejszenie opacity dla opisu (`description`) i nazwy źródła w przeczytanych artykułach.
- **Efekt wizualny**: Cały kafelek będzie sprawiał wrażenie "nieaktywnego" lub "zużytego", kierując wzrok na nowe, jaskrawe treści.

### 2. Optymalizacja Sekcji "Dla Ciebie" (CategoryNewsList)
Udoskonalimy horyzontalny pasek rekomendacji na szczycie kategorii "Wszystkie".

#### [MODIFY] [category_news_list.dart](file:///D:/Apps/prasowka/lib/widgets/category_news_list.dart)
- **Ograniczenie do Top 3**: Zgodnie z planem, skupimy się na 3 najmocniejszych rekomendacjach, aby nie przytłaczać użytkownika.
- **Stylizacja paska**: Poprawa marginesów i dodanie delikatnego cienia/tła pod sekcją "DLA CIEBIE", aby wizualnie oddzielić ją od reszty listy.

### 3. Precyzyjne Śledzenie Czytania (ArticleDetailScreen)
Upewnimy się, że Sowa poprawnie zapamiętuje postęp lektury.

#### [MODIFY] [article_detail_screen.dart](file:///D:/Apps/prasowka/lib/screens/article_detail_screen.dart)
- Skrócenie progu "przeczytania" z 30s na 20s (bardziej realistyczne dla krótkich newsów mobilnych).
- Automatyczne oznaczanie jako przeczytane natychmiast po dotarciu do dołu artykułu (Scroll Listener).

## Verification Plan

### Manual Verification
1.  **Hot Restart** aplikacji.
2.  Wejście w dowolny artykuł i spędzenie w nim 20 sekund.
3.  Powrót do listy -> sprawdzenie czy artykuł jest wyraźnie przyciemniony.
4.  Przewinięcie do dołu długiego artykułu -> sprawdzenie czy od razu po powrocie jest oznaczony jako przeczytany.
5.  Sprawdzenie sekcji "Dla Ciebie" w zakładce "Wszystkie" (czy zawiera dokładnie 3 pozycje).
