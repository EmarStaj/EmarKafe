import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emar_kafe/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Localization (i18n) Tests', () {
    test('Supported locales include Turkish (tr) and English (en)', () {
      final locales = AppLocalizations.supportedLocales;
      expect(locales.any((l) => l.languageCode == 'tr'), true);
      expect(locales.any((l) => l.languageCode == 'en'), true);
    });

    testWidgets('Renders Turkish translations by default', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return Scaffold(
                body: Column(
                  children: [
                    Text(l10n.appName),
                    Text(l10n.home),
                    Text(l10n.cart),
                    Text(l10n.wallet),
                    Text(l10n.checkout),
                    Text(l10n.loyaltyRewardInfo),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(l10n.appName, 'EMAR Kafe');
      expect(l10n.home, 'Anasayfa');
      expect(l10n.cart, 'Sepetim');
      expect(l10n.wallet, 'Cüzdanım');
      expect(l10n.checkout, 'Siparişi Tamamla');
      expect(l10n.loyaltyRewardInfo, '5 Siparişte 1 Kahve Hediye!');

      expect(find.text('EMAR Kafe'), findsOneWidget);
      expect(find.text('Anasayfa'), findsOneWidget);
      expect(find.text('Sepetim'), findsOneWidget);
      expect(find.text('Cüzdanım'), findsOneWidget);
      expect(find.text('Siparişi Tamamla'), findsOneWidget);
      expect(find.text('5 Siparişte 1 Kahve Hediye!'), findsOneWidget);
    });

    testWidgets('Renders English translations when locale is en', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return Scaffold(
                body: Column(
                  children: [
                    Text(l10n.appName),
                    Text(l10n.home),
                    Text(l10n.cart),
                    Text(l10n.wallet),
                    Text(l10n.checkout),
                    Text(l10n.loyaltyRewardInfo),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      expect(l10n.appName, 'EMAR Coffee');
      expect(l10n.home, 'Home');
      expect(l10n.cart, 'My Cart');
      expect(l10n.wallet, 'My Wallet');
      expect(l10n.checkout, 'Complete Order');
      expect(l10n.loyaltyRewardInfo, '1 Free Coffee Every 5 Orders!');

      expect(find.text('EMAR Coffee'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('My Cart'), findsOneWidget);
      expect(find.text('My Wallet'), findsOneWidget);
      expect(find.text('Complete Order'), findsOneWidget);
      expect(find.text('1 Free Coffee Every 5 Orders!'), findsOneWidget);
    });
  });
}
