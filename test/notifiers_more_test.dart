import 'package:flutter_test/flutter_test.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/state/notifiers/auth_notifier.dart';
import 'package:emar_kafe/state/notifiers/cart_notifier.dart';
import 'package:emar_kafe/state/notifiers/order_notifier.dart';
import 'package:emar_kafe/state/notifiers/wallet_notifier.dart';
import 'package:emar_kafe/state/notifiers/staff_notifier.dart';
import 'package:emar_kafe/state/notifiers/stock_notifier.dart';
import 'package:emar_kafe/state/notifiers/menu_notifier.dart';
import 'package:emar_kafe/models/product.dart';
import 'package:emar_kafe/models/cart_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/widgets.dart'; // for AppLifecycleState
import 'dart:async';

class MockApiService2 extends ApiService {
  @override Future<Map<String, dynamic>> getMenu({int page = 1, int limit = 20, String? categoryId, String? search, String? branchId}) async {
    if (page == 1) return {'data': [{'id': 'p1', 'name': 'P1', 'base_price': 10, 'category_id': 'c'}]};
    return {'data': []}; // empty for page 2
  }
  @override Future<Map<String, dynamic>> getLoyaltyProgress() async {
    return {'data': {'progress': [{'current_count': 5}], 'rewards': [{'status': 'earned'}]}};
  }
  @override Future<Map<String, dynamic>> getCart() async {
    return {'data': {'items': [{'id': 'c1', 'product_id': 'p1', 'quantity': 1, 'options': [{'id': 'opt1', 'name': 'O1', 'price_delta': 0}]}]}};
  }
  @override Future<List<String>> addToCart(String productId, int quantity, {List<dynamic>? options}) async { return []; }
  @override Future<void> updateCartItem(String cartItemId, int qty) async {}
  @override Future<List<dynamic>> getMyOrders() async { return []; }
  @override Future<Map<String, dynamic>> getWalletBalance() async { return {'data': {'balance': 100}}; }
  @override Future<void> placeOrder(String branchId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Remaining Notifiers Coverage', () {
    test('MenuNotifier coverage', () async {
      final api = MockApiService2();
      final menu = MenuNotifier(api);
      expect(menu.isLoading, false);
      expect(menu.hasMore, true);
      
      await menu.fetchFirstPage();
      expect(menu.products.length, 1);
      
      await menu.fetchNextPage();
      expect(menu.hasMore, false);
      
      await menu.fetchNextPage(); // should return early
    });

    test('OrderNotifier loyalty & lifecycle coverage', () async {
      final api = MockApiService2();
      final auth = AuthNotifier(api);
      auth.role = UserRole.customer;
      auth.loggedIn = true;
      final cart = CartNotifier(api, auth);
      final wallet = WalletNotifier(api, auth);
      final orders = OrderNotifier(api, auth, cart, wallet);

      await orders.fetchLoyalty();
      expect(orders.loyaltyProgress, 5);
      expect(orders.freeCoffeesEarned, 1);

      orders.didChangeAppLifecycleState(AppLifecycleState.resumed);
      orders.didChangeAppLifecycleState(AppLifecycleState.paused);
      
      await orders.fetchOrders();
      try {
        await orders.placeOrder(useWallet: true);
      } catch (_) {}

      orders.dispose();
    });

    test('WalletNotifier edge cases', () async {
      final api = MockApiService2();
      final auth = AuthNotifier(api);
      final wallet = WalletNotifier(api, auth);
      await wallet.fetchWalletBalance();
    });

    test('CartNotifier generateLocalId and update', () async {
      final api = MockApiService2();
      final auth = AuthNotifier(api);
      final cart = CartNotifier(api, auth);
      await cart.fetchCart();
      await cart.changeQty('p1-opt1', 1);
    });

    test('StockNotifier currentBranchOutOfStock', () {
      final api = MockApiService2();
      final auth = AuthNotifier(api);
      auth.selectBranch('b1');
      final stock = StockNotifier(api, auth);
      expect(stock.currentBranchOutOfStock.isEmpty, true);
    });

    test('AuthNotifier roles', () {
      expect(UserRole.customer.label, 'Müşteri');
      expect(UserRole.barista.label, 'Barista');
      expect(UserRole.manager.label, 'Yönetici');
      expect(UserRole.branchManager.label, 'Şube Yöneticisi');
      expect(UserRole.admin.label, 'Sistem Yöneticisi');
    });
  });
}
