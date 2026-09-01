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

## Konfiguracja Firebase — checklista

### 1. Projekt Firebase

1. Utwórz projekt na [Firebase Console](https://console.firebase.google.com/)
2. Dodaj aplikację Android (`com.example.prasowka` lub właściwy package name)
3. Pobierz `google-services.json` → umieść w `android/app/`

### 2. Usługi Firebase (włącz w konsoli)

| Usługa | Wymagana | Uwagi |
|--------|----------|-------|
| Authentication | Tak | Włącz metody: **Email/Password** i **Google** |
| Cloud Firestore | Tak | Utwórz bazę danych (tryb testowy na start) |
| Remote Config | Tak | Przechowuje klucze API (SportDB, TheSportsDB, NewsAPI) |
| Crashlytics | Opcjonalnie | Raportowanie błędów |

### 3. Google Sign-In — konfiguracja SHA

Aby logowanie Google działało, dodaj fingerprinty SHA w konsoli Firebase (Project Settings → Android app):

```bash
# SHA-1 (wymagane dla Google Sign-In)
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android

# SHA-256 (wymagane dla App Links / Dynamic Links)
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -storetype PKCS12
```

Dla builda release dodaj też SHA z klucza release:
```bash
keytool -list -v -alias <your-key-alias> -keystore <path-to-release-keystore>
```

> Bez SHA-1 Google Sign-In zwróci błąd `12500` ( DEVELOPER_ERROR).

### 4. Remote Config — klucze API

W konsoli Firebase → Remote Config, dodaj parametry:

| Parametr | Opis | Przykład wartości |
|----------|------|-------------------|
| `newsapi_key` | Klucz API NewsAPI.org | `abc123...` |
| `sportdb_api_key` | Klucz API TheSportsDB (Flashscore) | `abc123...` |
| `thesportsdb_api_key` | Klucz API TheSportsDB (events) | `abc123...` |

Wartości pobierane są przy starcie aplikacji. W trybie dev można użyć pliku `.env` (zobacz `.env.example`).

### 5. Firestore — Security Rules

Reguły izolują dane użytkowników — każdy widzi tylko swoje kolekcje:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Dane lokalne vs chmura

| Dane | Lokalne (Hive) | Chmura (Firestore) | Uwagi |
|------|----------------|-------------------|-------|
| Artykuły | Tak | Tak (szyfrowane) | Pull nie tworzy nowych — tylko merguje flagi (isSaved, isRead...) |
| Ustawienia | Tak | Tak | Nowe urządzenie: pobiera zdalne; istniejące: uzupełnia brakujące klucze |
| Zainteresowania (score'y tagów) | Tak | Tak (szyfrowane) | Pull: tylko brakujące tagi |
| Zapisane artykuły | Tak | Tak (flagi) | Symetryczny merge flag |
| Tagi użytkownika | Tak | Tak (szyfrowane) | Pull: tylko brakujące |
| Kategorie / źródła | Tak | Tak | Pull: tylko brakujące |
| Historia czytania | Tak | Tak (szyfrowane) | Pull: tylko brakujące |
| Pogoda, wyniki sportowe | Tak | NIE | Tylko lokalnie (cache) |
| Pliki .env / klucze API | NIE | Remote Config | Nie w repo, nie w APK |

> **Szyfrowanie:** Dane wrażliwe (artykuły, zainteresowania, historia) są szyfrowane AES-256-CBC przed wysłaniem do Firestore. Klucz pochodzi z hasła użytkownika (email login) lub UID (Google login).

## Bezpieczeństwo

- Klucze API pobierane z Firebase Remote Config (nie są wbudowane w APK)
- Dane użytkownika szyfrowane AES-256 przed wysłaniem do Firestore (klucz z hasła/konta)
- Cała komunikacja po HTTPS (TLS)
- Raportowanie błędów: Firebase Crashlytics
