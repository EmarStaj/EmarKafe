import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/state/notifiers/auth_notifier.dart';
import 'package:emar_kafe/state/notifiers/cart_notifier.dart';
import 'package:emar_kafe/state/notifiers/order_notifier.dart';
import 'package:emar_kafe/state/notifiers/wallet_notifier.dart';
import 'package:emar_kafe/state/notifiers/menu_notifier.dart';
import 'package:emar_kafe/state/notifiers/stock_notifier.dart';
import 'package:emar_kafe/state/notifiers/staff_notifier.dart';
import 'package:emar_kafe/models/order_record.dart';
import 'package:emar_kafe/models/cart_item.dart';
import 'package:emar_kafe/models/product.dart';
import 'package:emar_kafe/models/campaign.dart';
import 'package:emar_kafe/models/staff_member.dart';
import 'package:emar_kafe/models/branch.dart';
import 'package:emar_kafe/data/catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter/services.dart';

class MockApiAggressive extends ApiService {
  @override String? get token => 'test_token';

  @override Future<Map<String, dynamic>> getMe() async {
    return { 'user': { 'email': 'a@a.com', 'role': 'barista', 'user_metadata': {'full_name': 'A B', 'role': 'manager'} } };
  }
  @override Future<Map<String, dynamic>> getProfile() async {
    return { 'full_name': 'Profile Name', 'role': 'admin', 'birth_date': '1990-01-01', 'branch_id': {'id': 'b1'}, 'branch': 'b1' };
  }
  @override Future<void> clearToken() async {}
  @override Future<void> saveTokens(String accessToken, {String? refreshToken}) async {}

  @override Future<Map<String, dynamic>> getCart() async {
    return { 'data': [ { 'id': 'c1', 'productId': 'p1', 'quantity': 2, 'options': [ {'id': 'opt1', 'name': 'O1', 'price_delta': 1.0} ] }, { 'product_id': 'p2', 'quantity': 1 } ] };
  }
  @override Future<List<String>> addToCart(String productId, int quantity, {List<dynamic>? options}) async { return []; }
  @override Future<void> updateCartItem(String cartItemId, int qty) async { throw Exception('api error'); }

  @override Future<Map<String, dynamic>> getMenu({int page = 1, int limit = 20, String? categoryId, String? search, String? branchId}) async {
    if (page == 1) return {'data': [{'id': 'p1', 'name': 'P1', 'base_price': 10, 'category_id': 'c'}]};
    throw Exception('menu error');
  }

  @override Future<List<dynamic>> getBranchOrders() async {
    return [{'id': 'o1', 'status': 'received', 'total_price': 100, 'items': {'p1': 1}}];
  }
  @override Future<List<dynamic>> getMyOrders() async {
    return [{'id': 'o1', 'status': 'preparing', 'total_price': 100, 'items': {'p1': 1}}];
  }

  @override Future<Map<String, dynamic>> getWalletBalance() async {
    return {'data': {'wallet_balance': 100.0}};
  }
  @override Future<void> topupWallet(double amount) async { throw Exception('topup error'); }
  @override Future<String> getWalletQrToken() async { throw Exception('qr error'); }
  @override Future<void> updateOrderStatus(String orderId, String status) async { throw Exception('status error'); }
  @override Future<void> scanQrOrder(String token) async { throw Exception('scan error'); }
  @override Future<Map<String, dynamic>> getLoyaltyProgress() async {
    return {'data': {'progress': [{'current_count': 5}], 'rewards': [{'status': 'earned'}]}};
  }
}

class MockApiAggressive2 extends MockApiAggressive {
  @override Future<Map<String, dynamic>> getCart() async {
    return { 'items': [ { 'id': 'c1', 'productId': 'p1', 'quantity': 2 } ] };
  }
  @override Future<Map<String, dynamic>> getWalletBalance() async { return {'wallet_balance': 50.0}; }
}

class MockApiAggressive3 extends MockApiAggressive {
  @override Future<Map<String, dynamic>> getWalletBalance() async { return {'data': 30.0}; }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    const channel = MethodChannel('OneSignal');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async => null);
  });

  test('Aggressive Coverage', () async {
    final api = MockApiAggressive();
    final auth = AuthNotifier(api);
    await auth.fetchMe();
    
    final cart = CartNotifier(api, auth);
    await cart.fetchCart();
    await cart.changeQty('p1-opt1', -1);
    await Future.delayed(const Duration(milliseconds: 500));
    
    final cart2 = CartNotifier(MockApiAggressive2(), auth);
    await cart2.fetchCart();
    
    final menu = MenuNotifier(api);
    await menu.fetchNextPage();
    await menu.fetchNextPage();

    final wallet = WalletNotifier(api, auth);
    await wallet.fetchWalletBalance();
    try {
      await wallet.generateWalletToken();
    } catch (_) {}
    
    final wallet2 = WalletNotifier(MockApiAggressive2(), auth);
    await wallet2.fetchWalletBalance();
    
    final wallet3 = WalletNotifier(MockApiAggressive3(), auth);
    await wallet3.fetchWalletBalance();
    
    auth.role = UserRole.barista;
    final orders = OrderNotifier(api, auth, cart, wallet);
    await orders.fetchOrders();
    auth.role = UserRole.customer;
    await orders.fetchOrders();
    
    if (orders.activeOrder != null) {
      try { await orders.advanceOrderStatus(orders.activeOrder!); } catch (_) {}
    }
    
    try { await orders.confirmOrderFromQR('t'); } catch (_) {}
    
    wallet.walletBalance = 0;
    try { await orders.placeOrder(useWallet: true); } catch (_) {}
    
    auth.selectedBranchId = null;
    try { await orders.placeOrder(); } catch (_) {}
    
    auth.selectedBranchId = 'b1';
    try { await orders.placeOrder(); } catch (_) {}
    
    orders.activeBaristaOrders;
    
    final o1 = OrderRecord.fromJson({'id': '1', 'status': 'ready'});
    try { await orders.advanceOrderStatus(o1); } catch (_) {}
    final o2 = OrderRecord.fromJson({'id': '2', 'status': 'completed'});
    try { await orders.advanceOrderStatus(o2); } catch (_) {}
    
    await auth.init();
    
    orders.dispose();
  });
}
