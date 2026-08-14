import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:emar_kafe/models/product.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/state/app_state.dart';
import 'package:emar_kafe/state/notifiers/menu_notifier.dart';
import 'package:emar_kafe/widgets/loyalty_card.dart';
import 'package:emar_kafe/widgets/product_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('UI Components Widget Tests', () {
    testWidgets('LoyaltyCard renders progress and stamps correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoyaltyCard(progress: 3, freeCoffeesEarned: 1),
          ),
        ),
      );

      expect(find.text('3/5'), findsOneWidget);
      expect(find.text('5 Siparişte 1 Kahve Hediye!'), findsOneWidget);
      expect(find.text('1 Bedava İçecek Kullanılabilir'), findsOneWidget);
    });

    testWidgets('ProductCard displays product info and price correctly', (WidgetTester tester) async {
      const product = Product(
        id: 'p-espresso',
        name: 'Espresso',
        category: ProductCategory.hotCoffee,
        price: 55.0,
        icon: '☕',
        rating: 4.9,
        ratingCount: 88,
      );

      final api = ApiService();
      final auth = AuthNotifier(api);
      final cart = CartNotifier(api, auth);
      final wallet = WalletNotifier(api, auth);
      final orders = OrderNotifier(api, auth, cart, wallet);
      orders.stopPolling(); // Stop polling timer during widget test
      final stock = StockNotifier(api, auth);
      final menu = MenuNotifier(api);
      final appState = AppState(auth, cart, orders, wallet, stock, menu);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: Scaffold(
              body: ProductCard(product: product, onTap: () {}),
            ),
          ),
        ),
      );

      expect(find.text('Espresso'), findsOneWidget);
      expect(find.text('55₺'), findsOneWidget);
      expect(find.text('☕'), findsOneWidget);

      await tester.pumpWidget(const SizedBox()); // Unmount
    });
  });
}
