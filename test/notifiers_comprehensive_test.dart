import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/state/notifiers/auth_notifier.dart';
import 'package:emar_kafe/state/notifiers/cart_notifier.dart';
import 'package:emar_kafe/state/notifiers/order_notifier.dart';
import 'package:emar_kafe/state/notifiers/wallet_notifier.dart';
import 'package:emar_kafe/state/notifiers/staff_notifier.dart';
import 'package:emar_kafe/models/product.dart';
import 'package:emar_kafe/models/cart_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';

class MockApiService extends ApiService {
  bool shouldFail = false;
  @override String? get token => 'dummy_token';
  @override Future<void> init() async {}
  @override Future<void> saveTokens(String token, {String? refreshToken}) async {}
  @override Future<void> clearToken() async {}
  
  @override Future<Map<String, dynamic>> getMe() async {
    if (shouldFail) throw Exception('API Error');
    return {'user': {'email': 'test@test.com', 'role': 'admin'}};
  }
  @override Future<Map<String, dynamic>> getProfile() async {
    if (shouldFail) throw Exception('API Error');
    return {'full_name': 'Test User Profile', 'role': 'admin', 'branch_id': 'b-1'};
  }
  @override Future<Map<String, dynamic>> login(String email, String password) async {
    if (shouldFail) throw Exception('API Error');
    return {'token': 'dummy'};
  }
  @override Future<Map<String, dynamic>> register(String email, String phone, String password, String name, String birthDate, {String? role, String? branchId}) async {
    if (shouldFail) throw Exception('API Error');
    return {'token': 'dummy'};
  }
  @override Future<void> logout() async {}
  @override Future<void> updateEmail(String newEmail) async {}
  @override Future<void> deleteAccount() async {}
  @override Future<void> setDefaultBranch(String branchId) async {}
  
  @override Future<Map<String, dynamic>> getWalletBalance() async {
    if (shouldFail) throw Exception('API Error');
    return {'balance': 150.0, 'coins': 20.0};
  }
  @override Future<String> getWalletQrToken() async {
    if (shouldFail) throw Exception('API Error');
    return 'qr-token-123';
  }
  @override Future<void> topupWallet(double amount) async {
    if (shouldFail) throw Exception('API Error');
  }

  @override Future<Map<String, dynamic>> getCart() async {
    if (shouldFail) throw Exception('API Error');
    return {'items': [{'id': 'c-1', 'product_id': 'p-latte', 'quantity': 2, 'options': []}]};
  }
  @override Future<List<String>> addToCart(String productId, int quantity, {List<dynamic>? options}) async {
    if (shouldFail) throw Exception('API Error');
    return ['c-2'];
  }
  @override Future<void> updateCartItem(String cartItemId, int qty) async {
    if (shouldFail) throw Exception('API Error');
  }

  @override Future<void> placeOrder(String branchId) async {
    if (shouldFail) throw Exception('API Error');
  }
  @override Future<List<dynamic>> getMyOrders() async {
    if (shouldFail) throw Exception('API Error');
    return [{'id': 'o-1', 'status': 'completed', 'total_price': 50.0}];
  }
  @override Future<List<dynamic>> getBranchOrders() async {
    if (shouldFail) throw Exception('API Error');
    return [{'id': 'o-1', 'status': 'preparing', 'total_price': 50.0}];
  }
  @override Future<void> scanQrOrder(String qrToken) async {
    if (shouldFail) throw Exception('API Error');
  }
  @override Future<void> updateOrderStatus(String orderId, String status) async {
    if (shouldFail) throw Exception('API Error');
  }
  
  @override Future<List<dynamic>> getStaff({String? branchId}) async {
    if (shouldFail) throw Exception('API Error');
    return [{'id': 's-1', 'full_name': 'S1', 'role': 'barista'}];
  }
  @override Future<Map<String, dynamic>> createStaff({required String fullName, required String email, required String password, required String role, String? branchId}) async {
    if (shouldFail) throw Exception('API Error');
    return {'user': {}};
  }
  @override Future<void> deleteStaff(String staffId) async {
    if (shouldFail) throw Exception('API Error');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    const channel = MethodChannel('OneSignal');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return null;
    });
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Comprehensive Notifiers Tests', () {
    late MockApiService api;
    late AuthNotifier auth;
    
    setUp(() {
      api = MockApiService();
      auth = AuthNotifier(api);
    });

    test('AuthNotifier logic', () async {
      await auth.init();
      expect(auth.loggedIn, true);
      
      await auth.loginWithCredentials(email: 'a@a', password: 'p');
      await auth.register(name: 'n', email: 'a@a', phone: '1', password: 'p', birthDate: DateTime.now(), selectedRole: UserRole.customer, branch: 'b-1');

      api.shouldFail = true;
      await auth.loginWithCredentials(email: 'a@a', password: 'p');
      await auth.register(name: 'n', email: 'a@a', phone: '1', password: 'p', birthDate: DateTime.now(), selectedRole: UserRole.customer, branch: 'b-1');
      api.shouldFail = false;

      await auth.logout();
      await auth.updateEmail('new@a.com');
      await auth.deleteAccount();
      auth.selectBranch('b-2');
    });

    test('WalletNotifier logic', () async {
      final wallet = WalletNotifier(api, auth);
      await wallet.fetchWalletBalance();
      await wallet.generateWalletToken();
      api.shouldFail = true;
      await wallet.fetchWalletBalance();
      await wallet.generateWalletToken();
      api.shouldFail = false;
      await wallet.addWalletBalance(10);
    });

    test('CartNotifier logic', () async {
      final cart = CartNotifier(api, auth);
      await cart.fetchCart();
      await cart.addToCart('p1');
      
      final localIds = cart.cart.keys.toList();
      if (localIds.isNotEmpty) {
        await cart.changeQty(localIds.first, 1);
        await cart.changeQty(localIds.first, -1); 
      }
      
      api.shouldFail = true;
      await cart.fetchCart();
      await cart.addToCart('p1');
    });

    test('OrderNotifier logic', () async {
      final cart = CartNotifier(api, auth);
      final wallet = WalletNotifier(api, auth);
      final orders = OrderNotifier(api, auth, cart, wallet);
      orders.stopPolling();
      
      await orders.fetchOrders();
      await orders.placeOrder(useWallet: false);
      await orders.confirmOrderFromQR('token');

      if (orders.orderHistory.isNotEmpty) {
        await orders.advanceOrderStatus(orders.orderHistory.first);
        await orders.markPickedUp(orders.orderHistory.first);
      }

      api.shouldFail = true;
      await orders.fetchOrders();
      try {
        await orders.placeOrder();
      } catch (_) {}
    });

    test('StaffNotifier logic', () async {
      final staff = StaffNotifier(api);
      await staff.fetchStaff(branchId: 'b-1');
      await staff.createStaff(fullName: 'n', email: 'e', password: 'p', role: 'barista');
      await staff.deleteStaff('s-1');

      api.shouldFail = true;
      await staff.fetchStaff();
      await staff.createStaff(fullName: 'n', email: 'e', password: 'p', role: 'barista');
      await staff.deleteStaff('s-1');
    });
  });
}
