# Nowa Tożsamość Wizualna - Prasówka

Zrealizowałem Twoją wizję animowanego wejścia do aplikacji oraz poprawiłem ikony, aby wyglądały profesjonalnie na każdym urządzeniu.

## Co zostało zmienione?

### 1. Ikona Aplikacji (Perfect Fit)
- Skonfigurowałem tzw. **Adaptive Icons** dla Androida. Teraz głowa sowy jest wyśrodkowana na granatowym tle i idealnie wypełnia okrągły przycisk, bez ucinania krawędzi.
- Na iOS ikona również została odświeżona i dopasowana do standardów systemu.

### 2. Systemowy Splash Screen
- Zgodnie z prośbą, logo sowy na ekranie startowym (tym systemowym) zostało **zmniejszone**, dzięki czemu jest widoczne w całości i ma dużo oddechu.

### 3. Animacja Zderzenia (Custom Splash)
To najbardziej efektowna część zmian. Stworzyłem dedykowany ekran `SplashScreen`, który:
- **Wjazd z boków:** Obrazek `Pra.png` wjeżdża dynamicznie z lewej strony, a `sówka.png` z prawej.
- **Efekt Kolizji:** W momencie zderzenia ekran wykonuje lekki **wstrząs (Shake effect)**, co nadaje animacji "ciężaru".
- **Eksplozja Cząsteczek:** W miejscu zderzenia pojawia się **kurz i odłamki** (wygenerowane algorytmicznie cząsteczki w kolorach złota i szarości), co symuluje zderzenie twardych obiektów.
- **Transformacja:** Po zderzeniu tekst zmienia się w finalną formę `sówka 2.png` (z Twoimi barwami), a następnie aplikacja płynnie przechodzi do czytnika newsów.

## Jak to zobaczyć?

1. Zamknij całkowicie aplikację i uruchom ją ponownie.
2. Zobaczysz granatowy ekran z małą sową (systemowy splash).
3. Następnie ruszy animacja zderzenia "Pra" i "sówka" z efektami cząsteczek.
4. Po ok. 3 sekundach znajdziesz się w aplikacji.

> [!TIP]
> Animacja jest zoptymalizowana pod kątem wydajności — cząsteczki są rysowane bezpośrednio na karcie graficznej (Canvas API), więc nie obciążają procesora.

## Pliki zasobów
Wszystkie dostarczone pliki: `Pra.png`, `sówka.png`, `sówka 2.png` oraz `logo.png` zostały poprawnie dodane do projektu i są używane w animacji.
