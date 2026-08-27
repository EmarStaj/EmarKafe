import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:emar_kafe/router/app_router.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/models/staff_member.dart';
import 'package:emar_kafe/state/app_state.dart';
import 'package:emar_kafe/state/notifiers/auth_notifier.dart';
import 'package:emar_kafe/state/notifiers/cart_notifier.dart';
import 'package:emar_kafe/state/notifiers/order_notifier.dart';
import 'package:emar_kafe/state/notifiers/wallet_notifier.dart';
import 'package:emar_kafe/state/notifiers/stock_notifier.dart';
import 'package:emar_kafe/state/notifiers/menu_notifier.dart';
import 'package:emar_kafe/state/notifiers/staff_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MockApiForRouter extends ApiService {
  @override Future<Map<String, dynamic>> getMe() async => {'user': {'email': 'a@a', 'role': 'admin'}};
  @override Future<Map<String, dynamic>> login(String email, String password) async => {'token': 'tok', 'user': {'email': 'a@a', 'role': 'admin'}};
  @override Future<Map<String, dynamic>> getCart() async => {'data': {'items': []}};
  @override Future<List<dynamic>> getMyOrders() async => [];
  @override Future<List<dynamic>> getBranchOrders() async => [];
  @override Future<List<dynamic>> getStaff({String? branchId}) async => [];
  @override Future<Map<String, dynamic>> getLoyaltyProgress() async => {'data': {'progress': [], 'rewards': []}};
  @override Future<Map<String, dynamic>> getWalletBalance() async => {'data': {'balance': 100.0}};
  @override Future<Map<String, dynamic>> getMenu({int page = 1, int limit = 20, String? categoryId, String? search, String? branchId}) async => {'data': []};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('Unauthenticated user starts at CustomerShell', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final api = MockApiForRouter();
    final auth = AuthNotifier(api);
    final cart = CartNotifier(api, auth);
    final wallet = WalletNotifier(api, auth);
    final orders = OrderNotifier(api, auth, cart, wallet);
    final stock = StockNotifier(api, auth);
    final menu = MenuNotifier(api);
    final staff = StaffNotifier(api);
    final appState = AppState(auth, cart, orders, wallet, stock, menu, staff);

    final router = AppRouter.createRouter(auth);

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
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('EMAR Kafe'), findsWidgets);
    expect(find.text('Sepetim'), findsOneWidget);

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

  testWidgets('Barista user is redirected to BaristaScreen', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final api = MockApiForRouter();
    final auth = AuthNotifier(api);
    auth.loggedIn = true;
    auth.role = UserRole.barista;

    final cart = CartNotifier(api, auth);
    final wallet = WalletNotifier(api, auth);
    final orders = OrderNotifier(api, auth, cart, wallet);
    final stock = StockNotifier(api, auth);
    final menu = MenuNotifier(api);
    final staff = StaffNotifier(api);
    final appState = AppState(auth, cart, orders, wallet, stock, menu, staff);

    final router = AppRouter.createRouter(auth);

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
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Barista'), findsWidgets);
    expect(find.textContaining('Bugün Tamamlanan'), findsOneWidget);

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

  testWidgets('Admin user is redirected to AdminScreen', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final api = MockApiForRouter();
    final auth = AuthNotifier(api);
    auth.loggedIn = true;
    auth.role = UserRole.admin;

    final cart = CartNotifier(api, auth);
    final wallet = WalletNotifier(api, auth);
    final orders = OrderNotifier(api, auth, cart, wallet);
    final stock = StockNotifier(api, auth);
    final menu = MenuNotifier(api);
    final staff = StaffNotifier(api);
    final appState = AppState(auth, cart, orders, wallet, stock, menu, staff);

    final router = AppRouter.createRouter(auth);

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
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Admin · Genel Bakış'), findsOneWidget);

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
