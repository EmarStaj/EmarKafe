import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:emar_kafe/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    testWidgets('verify app starts', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Ensure the app has loaded by finding MaterialApp or similar root widget
      expect(find.byType(MaterialApp), findsOneWidget); 
    });
  });
}
