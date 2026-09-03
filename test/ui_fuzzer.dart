import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> fuzzUI(WidgetTester tester) async {
  for (int j = 0; j < 3; j++) {
    final elements = find.byWidgetPredicate((widget) {
      return widget is InkWell || widget is GestureDetector || widget is ElevatedButton || widget is TextButton || widget is IconButton || widget is FloatingActionButton || widget is ListTile;
    }).evaluate().toList();
    
    for (var element in elements) {
      try {
        await tester.tap(find.byWidget(element.widget));
        await tester.pumpAndSettle(const Duration(milliseconds: 50));
      } catch (_) {}
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
  }
}
