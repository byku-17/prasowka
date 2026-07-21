# Plan: Rozbudowa Treści (Nauka i Motoryzacja) oraz Ulepszenie Ustawień

Celem jest dodanie dwóch nowych, bogatych w treść kategorii (NAUKA i MOTORYZACJA) oraz znaczące ulepszenie ekranu ustawień poprzez grupowanie źródeł i dodanie funkcji "Zaznacz wszystkie".

## Proponowane Zmiany

### 1. Nowe Kategorie i Źródła (Models)

#### [MODIFY] [news_category.dart](file:///D:/Apps/prasowka/lib/models/news_category.dart)
Dodanie kategorii:
- **Nauka** (ID: `science`, Ikona: `science`)
- **Motoryzacja** (ID: `automotive`, Ikona: `directions_car`)

#### [MODIFY] [news_source.dart](file:///D:/Apps/prasowka/lib/models/news_source.dart)
Dodanie ponad 30 nowych źródeł:

**Kategoria NAUKA (Global & PL):**
- **Global:** Nature, Science, PLOS ONE, Scientific American, NASA.
- **Medycyna:** NEJM, The Lancet, JAMA, BMJ, Puls Medycyny.
- **PL:** Nauka w Polsce (PAP), Kwantowo.pl, Projekt Pulsar, Dziennik Naukowy, Medycyna Praktyczna.

**Kategoria MOTORYZACJA (PL & Global):**
- **Testy/Info:** Autocentrum, Autokult, Onet Moto, Moto.pl, Interia Motoryzacja.
- **Prasa:** Auto Świat, Magazyn Auto (Motor), Top Gear (Global), Automobilista.
- **E-mobility/Tech:** Elektrowóz, Autoblog.pl, GreenCarCongress.
- **Biznes/Sport:** WRC, Sokół Około F1.

### 2. Logika Biznesowa (SettingsProvider)

#### [MODIFY] [settings_provider.dart](file:///D:/Apps/prasowka/lib/providers/settings_provider.dart)
- Dodanie metod `toggleAllSourcesInCategory(String categoryId, bool enable)` oraz `toggleAllSources(bool enable)`.
- Usprawnienie zapisu do Hive, aby operacje masowe były wydajne.

### 3. Interfejs Użytkownika (SettingsScreen)

#### [MODIFY] [settings_screen.dart](file:///D:/Apps/prasowka/lib/screens/settings_screen.dart)
- **Grupowanie:** Lista źródeł nie będzie już jedną długą listą, ale zostanie podzielona na sekcje (headers) odpowiadające kategoriom.
- **Masowe akcje:** Przy każdym nagłówku kategorii pojawi się przycisk "Zaznacz wszystkie" / "Odznacz wszystkie".
- **Dynamiczne UI:** Usprawnienie przełączników, aby reagowały natychmiast na zmiany masowe.

## Plan Weryfikacji

### Testy Manualne
1. **Grupowanie:** Sprawdzenie w ustawieniach, czy źródła o tematyce F1 są pod nagłówkiem "Sport", a Nature pod "Nauka".
2. **Masowe Zaznaczanie:** Kliknięcie "Zaznacz wszystkie" w kategorii Motoryzacja i weryfikacja na ekranie głównym, czy wszystkie portale (Autocentrum, Autokult itd.) są aktywne.
3. **Nowe Zakładki:** Sprawdzenie, czy na ekranie głównym pojawiły się zakładki NAUKA i MOTORYZACJA.
4. **Wydajność:** Upewnienie się, że pobieranie z tak ogromnej bazy (ok. 100 źródeł) nie powoduje błędów "timeout" (optymalizacja równoległa).
