import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:emar_kafe/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('App renders EMAR Kafe home and branding', (WidgetTester tester) async {
    await tester.pumpWidget(const EmarKafeApp());
    await tester.pump();

    expect(find.text('EMAR Kafe'), findsWidgets);
    expect(find.text('Sepetim'), findsOneWidget);

    // Unmount to dispose providers and cancel polling timers cleanly
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
