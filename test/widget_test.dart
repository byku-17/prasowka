// This is a basic Flutter widget test.
import 'package:flutter_test/flutter_test.dart';
import 'package:prasowka/main.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // We don't have a counter anymore, so we just check if it builds.
    await tester.pumpWidget(const PrasowkaApp());
  });
}
