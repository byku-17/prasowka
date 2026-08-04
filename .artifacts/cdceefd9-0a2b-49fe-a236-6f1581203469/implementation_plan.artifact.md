# Plan Naprawy V5.5: Spójność Powiadomień (In-App WebView)

Zgodnie z Twoim życzeniem, wdrażamy pierwszy punkt z planu szlifowania — integrację powiadomień systemowych z naszą wewnętrzną przeglądarką. Od teraz kliknięcie w powiadomienie nie będzie już otwierać zewnętrznej przeglądarki (Chrome/Safari), lecz pokaże artykuł bezpośrednio w aplikacji.

## Proposed Changes

### 1. Reaktywność Powiadomień (BackgroundService)
Musimy umożliwić aplikacji "usłyszenie" kliknięcia w powiadomienie w czasie rzeczywistym.

#### [MODIFY] [background_service.dart](file:///D:/Apps/prasowka/lib/services/background_service.dart)
- Dodanie `StreamController<String>`, który będzie emitował URL artykułu po kliknięciu.
- Usunięcie bezpośredniego wywołania `url_launcher` w metodach `init` i `checkNotificationLaunch`.
- Przesyłanie payloadu (URL) do strumienia.

### 2. Obsługa Nawigacji (MainScreen)
UI musi reagować na sygnały z usługi tła i otwierać odpowiedni ekran.

#### [MODIFY] [main_screen.dart](file:///D:/Apps/prasowka/lib/screens/main_screen.dart)
- Subskrypcja strumienia z `BackgroundService` w metodzie `initState`.
- Obsługa "Cold Start": Sprawdzenie przy uruchomieniu, czy w `BackgroundService.pendingPayload` czeka URL z powiadomienia, które otworzyło aplikację.
- Automatyczne otwieranie `ArticleWebViewScreen` dla otrzymanego adresu URL.

## Verification Plan

### Manual Verification
1.  **Warm Start**: Uruchom aplikację, przejdź do ustawień i wyślij **TESTOWY ALERT**. Zminimalizuj aplikację (nie zamykaj). Kliknij w powiadomienie -> powinieneś wrócić do apki i od razu zobaczyć WebView z testową stroną.
2.  **Cold Start**: Całkowicie zamknij aplikację. Wyślij testowe powiadomienie (np. z konsoli lub jeśli masz taką możliwość w debugu). Kliknij w nie -> aplikacja powinna się uruchomić i od razu pokazać WebView.
