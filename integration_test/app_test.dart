import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:prasowka/main.dart' as app;

/// Smoke test aplikacji na realnym urządzeniu:
/// startuje pełna aplikacja (z Firebase/Workmanager), weryfikuje załadowanie
/// głównych zakładek i nawigację między nimi.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Hive.initFlutter();
    // Oznacz onboarding jako ukończony, żeby test wchodził od razu do MainScreen.
    final settingsBox = await Hive.openBox('settings');
    await settingsBox.put('onboardingCompleted', true);
  });

  testWidgets('startuje aplikacja i pokazuje główne zakładki', (tester) async {
    app.main();

    // Ostrożnie z pumpAndSettle — ekran "Dzisiaj" może mieć animację
    // shimmera przy ładowaniu treści, która nigdy się nie zatrzyma.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Zakładki nawigacji dolnej (BottomNavigationBar).
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Dzisiaj'), findsWidgets);
    expect(find.text('Tematy'), findsOneWidget);
    expect(find.text('Zapisane'), findsOneWidget);

    // Przejście do zakładki "Zapisane" (czysto lokalna, bez sieci).
    await tester.tap(find.text('Zapisane'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Brak zapisanych artykułów'), findsOneWidget);

    // Powrót na "Dzisiaj".
    await tester.tap(find.text('Dzisiaj'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    // Przycisk wyszukiwania (FAB) otwiera arkusz wyszukiwania.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TextField), findsWidgets);
  });
}
