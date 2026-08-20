import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/state/app_state.dart';
import 'package:emar_kafe/state/notifiers/menu_notifier.dart';
import 'package:emar_kafe/models/order_record.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('AppState Business Logic Tests', () {
    late ApiService api;
    late AuthNotifier auth;
    late CartNotifier cart;
    late WalletNotifier wallet;
    late OrderNotifier orders;
    late StockNotifier stock;
    late MenuNotifier menu;
    late AppState appState;

    setUp(() {
      api = ApiService();
      auth = AuthNotifier(api);
      cart = CartNotifier(api, auth);
      wallet = WalletNotifier(api, auth);
      orders = OrderNotifier(api, auth, cart, wallet);
      stock = StockNotifier(api, auth);
      menu = MenuNotifier(api);
      final staff = StaffNotifier(api);
      appState = AppState(auth, cart, orders, wallet, stock, menu, staff);
    });

    test('Initial state should be logged out with empty cart', () {
      expect(appState.loggedIn, false);
      expect(appState.cartItems.isEmpty, true);
      expect(appState.cartTotal, 0.0);
      expect(appState.loyaltyProgress, 0);
      expect(appState.freeCoffeesEarned, 0);
    });

    test('Selecting branch should update selectedBranchId', () {
      appState.selectBranch('branch-besiktas');
      expect(appState.selectedBranchId, 'branch-besiktas');
    });

    test('OrderStatus enum mappings and labels', () {
      expect(OrderStatus.created.name, 'created');
      expect(OrderStatus.preparing.name, 'preparing');
      expect(OrderStatus.ready.name, 'ready');
      expect(OrderStatus.completed.name, 'completed');
    });

    test('StockNotifier should toggle out-of-stock state', () {
      auth.selectBranch('branch-1');
      expect(stock.isOutOfStock('prod-1'), false);
      stock.toggleStock('prod-1');
      expect(stock.isOutOfStock('prod-1'), true);
      stock.toggleStock('prod-1');
      expect(stock.isOutOfStock('prod-1'), false);
    });
  });
}
