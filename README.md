# Prasówka

Spersonalizowany agregator polskich wiadomości na Androida (Flutter). Pobiera artykuły z kanałów RSS wybranych portali, filtruje je po Twoich zainteresowaniach i udostępnia wygodny czytnik z lektorem, tłumaczeniem, zapisami i synchronizacją w chmurze.

## Funkcje

- Lista wiadomości z wielu portali (RSS), filtrowana po zainteresowaniach i kategoriach
- Czytnik artykułów: czyszczenie treści, stopniowe ładowanie, regulacja czcionki
- Lektor (TTS) — czyta artykuły na głos po polsku
- Tłumaczenie artykułów z języków obcych na polski
- Zapisy, lajki, tagi, historia czytania
- Wyszukiwarka wiadomości
- Pasek wyników sportowych (LIVE) i lokalna pogoda
- Powiadomienia o wybranych tematach (praca w tle)
- Logowanie (e-mail / Google) i synchronizacja danych w chmurze (Firestore, szyfrowanie AES-256)

## Wymagania

- Flutter SDK 3.12+ (Dart 3.12)
- Konto Firebase (projekt z włączonymi: Authentication, Cloud Firestore, Remote Config, Crashlytics)
- Android Studio / SDK do budowy APK

## Budowa i uruchomienie

```bash
# 1. Skonfiguruj Firebase
#    - pobierz google-services.json z konsoli Firebase i wgraj do android/app/
#    - włącz usługi: Authentication, Firestore, Remote Config, Crashlytics

# 2. (opcjonalnie) Klucze API w pliku .env (dotyczy tylko trybu developerskiego)
cp .env.example .env
#    Uzupełnij klucze. W wersji produkcyjnej klucze pobierane są z Firebase Remote Config.

# 3. Zainstaluj zależności
flutter pub get

# 4. Uruchom na podłączonym urządzeniu / emulatorze
flutter run

# 5. (opcjonalnie) Zbuduj APK do instalacji
flutter build apk --release --no-tree-shake-icons
#    Wynik: build/app/outputs/flutter-apk/app-release.apk
```

> Uwaga: ikony są tworzone dynamicznie (kody z bazy lokalnej), dlatego build release wymaga flagi `--no-tree-shake-icons`.

## Konfiguracja Firebase

- `android/app/google-services.json` — konfiguracja projektu Firebase
- `lib/services/remote_config_service.dart` — klucze API pobierane zdalnie (Remote Config): `sportdb_api_key`, `thesportsdb_api_key`, `newsapi_key`

Plik `.env` **nie jest** dołączany do repozytorium ani do APK.

## Bezpieczeństwo

- Klucze API pobierane z Firebase Remote Config (nie są wbudowane w APK)
- Dane użytkownika szyfrowane AES-256 przed wysłaniem do Firestore (klucz z hasła/konta)
- Cała komunikacja po HTTPS (TLS)
- Raportowanie błędów: Firebase Crashlytics
