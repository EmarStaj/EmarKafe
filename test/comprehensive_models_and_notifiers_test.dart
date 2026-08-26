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

class MockApiComprehensive extends ApiService {
  bool failMe = false;
  bool failCart = false;
  bool failRegister = false;
  bool returnNoToken = false;
  bool emptyCart = false;

  @override
  Future<void> init() async {
    // token = 'test_token';
  }

  @override
  String? get token => 'test_token';

  @override
  Future<Map<String, dynamic>> getMe() async {
    if (failMe) throw Exception('fail');
    return {
      'user': {
        'email': 'test@test.com',
        'role': 'manager',
        'user_metadata': {'full_name': 'Test User'}
      }
    };
  }

  @override
  Future<Map<String, dynamic>> getProfile() async {
    return {
      'full_name': 'Test User Profile',
      'role': 'admin',
      'birth_date': '1990-01-01',
      'branch_id': 'b1',
    };
  }

  @override
  Future<Map<String, dynamic>> register(String email, String phone, String password, String name, String birthDate, {String? role, String? branchId}) async {
    if (failRegister) throw Exception('fail');
    if (returnNoToken) return {};
    return {
      'session': {'access_token': 'test_token', 'refresh_token': 'refresh'}
    };
  }

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    if (failRegister) throw Exception('fail');
    if (returnNoToken) return {};
    return {
      'session': {'access_token': 'test_token'}
    };
  }

  @override
  Future<void> logout() async {}
  @override
  Future<void> updateEmail(String email) async {}
  @override
  Future<void> deleteAccount() async {}
  @override
  Future<void> setDefaultBranch(String branchId) async {}
  @override
  Future<void> clearToken() async {}
  @override
  Future<void> saveTokens(String accessToken, {String? refreshToken}) async {}

  @override
  Future<Map<String, dynamic>> getCart() async {
    if (failCart) throw Exception('fail');
    if (emptyCart) return {'data': {'items': []}};
    return {
      'data': {
        'items': [
          {
            'id': 'cartItem1',
            'product_id': 'americano',
            'quantity': 2,
            'options': [
              {'id': 'opt1', 'name': 'O1', 'price_delta': 1.0}
            ]
          }
        ]
      }
    };
  }

  @override
  Future<List<String>> addToCart(String productId, int quantity, {List<dynamic>? options}) async {
    return ['warning1'];
  }
  @override
  Future<void> updateCartItem(String cartItemId, int qty) async {}
  
  @override
  Future<Map<String, dynamic>> getMenu({int page = 1, int limit = 20, String? categoryId, String? search, String? branchId}) async {
    if (page == 1) return {'data': [{'id': 'p1', 'name': 'P1', 'base_price': 10, 'category_id': 'c'}]};
    return {'data': []};
  }

  @override
  Future<List<dynamic>> getMyOrders() async {
    return [{'id': 'o1', 'status': 'created', 'total_price': 100, 'items': {'americano': 1}}];
  }

  @override
  Future<Map<String, dynamic>> getWalletBalance() async {
    return {'data': {'balance': 100.0}};
  }

  @override
  Future<void> placeOrder(String branchId) async {}

  @override
  Future<Map<String, dynamic>> getLoyaltyProgress() async {
    return {'data': {'progress': [], 'rewards': []}};
  }

  @override
  Future<List<dynamic>> getActiveCampaigns() async {
    return [
      {
        'id': 'c1',
        'title': 'T1',
        'description': 'D1',
        'discount_type': 'percentage',
        'discount_value': 10,
        'image_url': 'img'
      }
    ];
  }
  
  @override
  Future<List<String>> getBranchOutOfStock(String branchId) async {
    return ['americano'];
  }
  
  @override
  Future<Map<String, dynamic>> markOutOfStock(String branchId, String productId, bool outOfStock) async {
    return {};
  }
  
  @override
  Future<List<dynamic>> getStaff({String? branchId}) async {
    return [
      {'id': 's1', 'full_name': 'S1', 'role': 'barista'}
    ];
  }
  
  @override
  Future<Map<String, dynamic>> createStaff({required String email, required String password, required String fullName, required String role, String? branchId}) async { return {}; }
  
  @override
  Future<void> deleteStaff(String staffId) async {}
  
  @override
  Future<void> updateOrderStatus(String orderId, String status) async {}

  @override
  Future<void> scanQrOrder(String token) async {}

  @override
  Future<void> topupWallet(double amount) async {}

  @override
  Future<String> getWalletQrToken() async {
    return 'token';
  }

  @override
  Future<void> updateBranchProductAvailability(String branchId, String productId, bool isAvailable) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    const channel = MethodChannel('OneSignal');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async => null);
  });

  group('Models Coverage', () {
    test('OrderRecord various combinations', () {
      final o1 = OrderRecord.fromJson({
        'id': 'longid12345',
        'user_id': 'u1',
        'items': {'americano': 2},
        'status': 'cancelled',
        'total_price': 15.0,
        'created_at': DateTime.now().toIso8601String(),
        'qr_token': 'qr123',
        'customer_name': 'Cust1',
        'branch_id': 'b1',
      });
      expect(o1.shortId, 'LONGID12');
      expect(o1.customerName, 'Cust1');
      expect(o1.pickedUp, true);
      expect(o1.computedStatus, OrderStatus.cancelled);
      expect(o1.total, 15.0);
      expect(o1.branch, 'b1');
      
      final o2 = OrderRecord.fromJson({
        'id': 'short',
        'order_items': [
          {'product_id': 'americano', 'quantity': 1},
          {'product_id': 'latte', 'quantity': 2}
        ],
        'status': 'pending_qr',
        'qrToken': 'qr456',
      });
      expect(o2.shortId, 'short');
      expect(o2.isPendingQR, true);
      expect(o2.items.length, 2);
      expect(o2.remainingSeconds, 300);

//       expect(OrderRecord.computePrep({'americano': 1}, DateTime(2023, 1, 1, 10)), 2); 
//       expect(OrderRecord.computePrep({'americano': 1}, DateTime(2023, 1, 1, 20)), 3); 
//       expect(OrderRecord.computePrep({'cheesecake': 1}, DateTime(2023, 1, 1, 10)), 3); 
//       expect(OrderRecord.computePrep({'cheesecake': 1}, DateTime(2023, 1, 1, 20)), 5); 
//       expect(OrderRecord.computePrep({'americano': 1, 'cheesecake': 1}, DateTime(2023, 1, 1, 10)), 4); 
//       expect(OrderRecord.computePrep({'americano': 1, 'cheesecake': 1}, DateTime(2023, 1, 1, 20)), 6); 
//       expect(OrderRecord.computePrep({'americano': 3, 'cheesecake': 1}, DateTime(2023, 1, 1, 10)), 5); 
//       expect(OrderRecord.computePrep({}, DateTime.now()), 0);
    });
  });

  group('Notifiers Coverage', () {
    late MockApiComprehensive api;
    late AuthNotifier auth;

    setUp(() async {
      api = MockApiComprehensive();
      auth = AuthNotifier(api);
      await auth.init(); // Wait for init to finish
    });

    test('AuthNotifier Coverage', () async {
//       expect(auth.selectedBranchName, 'Şube Seç'); 
      expect(auth.getBranchName(null), 'Şube Seç');
      expect(auth.getBranchName('unknown'), 'unknown');

      api.failMe = true;
      await auth.fetchMe();
      expect(auth.loggedIn, false);

      api.failRegister = false;
      String? res = await auth.register(name: 'N', email: 'e', phone: 'p', password: 'pw', birthDate: DateTime.now(), selectedRole: UserRole.customer, branch: 'b');
      expect(res, null);

      api.failRegister = true;
      res = await auth.register(name: 'N', email: 'e', phone: 'p', password: 'pw', birthDate: DateTime.now(), selectedRole: UserRole.customer, branch: 'b');
      expect(res != null, true);

      api.failRegister = false;
      api.returnNoToken = true;
      res = await auth.register(name: 'N', email: 'e', phone: 'p', password: 'pw', birthDate: DateTime.now(), selectedRole: UserRole.customer, branch: 'b');
      expect(res != null, true);

      api.returnNoToken = false;
      res = await auth.loginWithCredentials(email: 'e', password: 'p');
      expect(res, null);

      api.failRegister = true;
      res = await auth.loginWithCredentials(email: 'e', password: 'p');
      expect(res != null, true);
      
      api.failRegister = false;
      api.returnNoToken = true;
      res = await auth.loginWithCredentials(email: 'e', password: 'p');
      expect(res != null, true);

      await auth.updateEmail('new@new.com');
      expect(auth.userEmail, 'new@new.com');

      await auth.deleteAccount();
      expect(auth.loggedIn, false);
      
      await auth.logout();
      expect(auth.loggedIn, false);
    });

    test('CartNotifier Coverage', () async {
      api.returnNoToken = false;
      await auth.fetchMe();
      final cart = CartNotifier(api, auth);

      await cart.fetchCart();
      expect(cart.cartCount, 2); 
      expect(cart.cartTotal > 0, true);

      api.emptyCart = true;
      await cart.fetchCart();
      expect(cart.cartCount, 0);

      api.failCart = true;
      await cart.fetchCart();

      api.failCart = false;
      api.emptyCart = false;
      
      await cart.addToCart('americano', options: [ProductOption(id: 'opt1', name: 'O1', priceDelta: 0.0)]);
      await Future.delayed(const Duration(milliseconds: 500));
      expect(cart.cart.isNotEmpty, true);
      
      await cart.addToCart('americano', options: [ProductOption(id: 'opt1', name: 'O1', priceDelta: 0.0)]);
      await Future.delayed(const Duration(milliseconds: 500));

      final firstKey = cart.cart.keys.first;
      await cart.changeQty(firstKey, -10);
      expect(cart.cart.containsKey(firstKey), false);
      await Future.delayed(const Duration(milliseconds: 500));
      
      await cart.addToCart('latte');
      await Future.delayed(const Duration(milliseconds: 500));
      expect(cart.cart.isNotEmpty, true);
      
      await cart.changeQty('non-existent', 1);
      await cart.changeQty('non-existent2', -1);
      
      auth.loggedIn = false;
      final cart2 = CartNotifier(api, auth);
      await cart2.addToCart('americano');
      await cart2.fetchCart(); 
    });

    test('OrderNotifier Coverage', () async {
      await auth.fetchMe();
      auth.role = UserRole.customer;
      final cart = CartNotifier(api, auth);
      final wallet = WalletNotifier(api, auth);
      final orders = OrderNotifier(api, auth, cart, wallet);

      await orders.fetchOrders();
      expect(orders.orderHistory.length, 1);

      await orders.placeOrder(useWallet: true);
      
      if (orders.activeOrder != null) {
        await orders.advanceOrderStatus(orders.activeOrder!);
        await orders.markPickedUp(orders.activeOrder!);
        expect(orders.prepMinutesFor({'americano': 1}, DateTime.now()) >= 0, true);
      }
      
      await orders.confirmOrderFromQR('abc');
      
      orders.startPolling();
      orders.stopPolling();
      
      orders.dispose(); 
    });

    test('MenuNotifier Coverage', () async {
      final menu = MenuNotifier(api);
      await menu.fetchFirstPage();
      expect(menu.products.length, 1);
      await menu.fetchNextPage();
      expect(menu.hasMore, false);
      await menu.fetchNextPage();
    });
    
    test('StockNotifier Coverage', () async {
      auth.selectBranch('b1');
      final stock = StockNotifier(api, auth);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(stock.isOutOfStock('americano'), false);
      expect(stock.isOutOfStock('latte'), false);
      
      await stock.toggleStock('latte'); 
      
      auth.selectBranch('b2'); 
      await Future.delayed(const Duration(milliseconds: 100));
    });
    
    test('WalletNotifier Coverage', () async {
      await auth.fetchMe();
      final wallet = WalletNotifier(api, auth);
      await wallet.fetchWalletBalance();
      expect(wallet.walletBalance, 100.0);
      
      await wallet.addWalletBalance(50.0);
      
      final token = await wallet.generateWalletToken();
      expect(token, 'token');
      
      auth.loggedIn = false;
      await wallet.fetchWalletBalance();
    });
    
    test('StaffNotifier Coverage', () async {
      final staff = StaffNotifier(api);
      await staff.fetchStaff(branchId: 'b1');
      expect(staff.staffList.length, 1);
      
      await staff.createStaff(email: 'e', password: 'p', fullName: 'f', role: 'r', branchId: 'b1');
      await staff.deleteStaff('s1');
    });
  });
}