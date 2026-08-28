import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:emar_kafe/models/product.dart';
import 'package:emar_kafe/models/cart_item.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/state/app_state.dart';
import 'package:emar_kafe/state/notifiers/auth_notifier.dart';
import 'package:emar_kafe/state/notifiers/cart_notifier.dart';
import 'package:emar_kafe/state/notifiers/order_notifier.dart';
import 'package:emar_kafe/state/notifiers/wallet_notifier.dart';
import 'package:emar_kafe/state/notifiers/stock_notifier.dart';
import 'package:emar_kafe/state/notifiers/menu_notifier.dart';
import 'package:emar_kafe/state/notifiers/staff_notifier.dart';
import 'package:emar_kafe/widgets/product_card.dart';
import 'package:emar_kafe/screens/customer/customer_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MockApiForGranular extends ApiService {
  @override Future<Map<String, dynamic>> getMe() async => {'user': {'id': 'u1', 'email': 'a@a', 'role': 'customer'}};
  @override Future<Map<String, dynamic>> login(String email, String password) async => {'token': 'tok', 'user': {'email': 'a@a', 'role': 'customer'}};
  @override Future<Map<String, dynamic>> getCart() async => {'data': {'items': []}};
  @override Future<List<dynamic>> getMyOrders() async => [];
  @override Future<List<dynamic>> getBranchOrders() async => [];
  @override Future<List<dynamic>> getStaff({String? branchId}) async => [];
  @override Future<Map<String, dynamic>> getLoyaltyProgress() async => {'data': {'progress': [], 'rewards': []}};
  @override Future<Map<String, dynamic>> getWalletBalance() async => {'data': {'balance': 100.0}};
  @override Future<List<dynamic>> getBranchProducts(String branchId) async => [];
  @override Future<Map<String, dynamic>> getMenu({int page = 1, int limit = 20, String? categoryId, String? search, String? branchId}) async => {'data': []};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('ProductCard rebuilds only when its specific quantity changes', (tester) async {
    final api = MockApiForGranular();
    final auth = AuthNotifier(api);
    final cart = CartNotifier(api, auth);
    final wallet = WalletNotifier(api, auth);
    final orders = OrderNotifier(api, auth, cart, wallet);
    final stock = StockNotifier(api, auth);
    final menu = MenuNotifier(api);
    final staff = StaffNotifier(api);
    final appState = AppState(auth, cart, orders, wallet, stock, menu, staff);

    const productA = Product(
      id: 'prod-a',
      name: 'Americano',
      category: ProductCategory.hotCoffee,
      price: 30.0,
      icon: '☕',
      rating: 4.8,
      ratingCount: 12,
    );

    const productB = Product(
      id: 'prod-b',
      name: 'Latte',
      category: ProductCategory.hotCoffee,
      price: 35.0,
      icon: '🥛',
      rating: 4.9,
      ratingCount: 20,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appState),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: cart),
          ChangeNotifierProvider.value(value: wallet),
          ChangeNotifierProvider.value(value: orders),
          ChangeNotifierProvider.value(value: stock),
          ChangeNotifierProvider.value(value: menu),
          ChangeNotifierProvider.value(value: staff),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ProductCard(product: productA, onTap: () {}),
                ProductCard(product: productB, onTap: () {}),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Americano'), findsOneWidget);
    expect(find.text('Latte'), findsOneWidget);
    expect(find.byKey(const ValueKey('stepper')), findsNothing);

    // Add productA to cart
    cart.cart['prod-a'] = CartItem(
      cartItemId: 'item-1',
      product: productA,
      quantity: 2,
    );
    cart.notifyListeners();
    await tester.pump();

    // Now productA has stepper with '2'
    expect(find.text('2'), findsOneWidget);

    // Update wallet balance (should NOT disturb ProductCard)
    wallet.walletBalance = 500.0;
    wallet.notifyListeners();
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    orders.dispose();
    auth.dispose();
    cart.dispose();
    wallet.dispose();
    stock.dispose();
    menu.dispose();
    staff.dispose();
    appState.dispose();
  });

  testWidgets('CustomerShell bottom bar badge updates reactively via Selector', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final api = MockApiForGranular();
    final auth = AuthNotifier(api);
    final cart = CartNotifier(api, auth);
    final wallet = WalletNotifier(api, auth);
    final orders = OrderNotifier(api, auth, cart, wallet);
    final stock = StockNotifier(api, auth);
    final menu = MenuNotifier(api);
    final staff = StaffNotifier(api);
    final appState = AppState(auth, cart, orders, wallet, stock, menu, staff);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appState),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: cart),
          ChangeNotifierProvider.value(value: wallet),
          ChangeNotifierProvider.value(value: orders),
          ChangeNotifierProvider.value(value: stock),
          ChangeNotifierProvider.value(value: menu),
          ChangeNotifierProvider.value(value: staff),
        ],
        child: const MaterialApp(
          home: CustomerShell(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sepetim'), findsOneWidget);
    expect(find.text('3'), findsNothing);

    // Update cart
    const product = Product(
      id: 'p-1',
      name: 'Espresso',
      category: ProductCategory.hotCoffee,
      price: 20.0,
      icon: '☕',
      rating: 4.5,
      ratingCount: 5,
    );
    cart.cart['p-1'] = CartItem(cartItemId: 'item-p1', product: product, quantity: 3);
    cart.notifyListeners();
    await tester.pump();

    expect(find.text('3'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    orders.dispose();
    auth.dispose();
    cart.dispose();
    wallet.dispose();
    stock.dispose();
    menu.dispose();
    staff.dispose();
    appState.dispose();
  });
}
