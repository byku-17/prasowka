# Zadania: V5.5 Spójność Powiadomień (WebView)

- [ ] Aktualizacja `BackgroundService`:
    - [ ] Dodanie `StreamController<String?> notificationStream`
    - [ ] Przesyłanie payloadu do strumienia w `onDidReceiveNotificationResponse`
    - [ ] Przesyłanie payloadu do strumienia w `checkNotificationLaunch`
    - [ ] Usunięcie metody `_openUrl`
- [ ] Aktualizacja `MainScreen`:
    - [ ] Dodanie `StreamSubscription` w `initState`
    - [ ] Implementacja metody `_handleNotificationUrl(url)`
    - [ ] Sprawdzenie `pendingPayload` przy starcie (Cold Start)
- [ ] Weryfikacja (Testowy alert Sowy)
- [ ] Commit zmian
