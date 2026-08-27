import 'package:flutter_test/flutter_test.dart';
import 'package:emar_kafe/services/realtime_service.dart';
import 'package:emar_kafe/state/notifiers/order_notifier.dart';
import 'package:emar_kafe/state/notifiers/auth_notifier.dart';
import 'package:emar_kafe/state/notifiers/cart_notifier.dart';
import 'package:emar_kafe/state/notifiers/wallet_notifier.dart';
import 'package:emar_kafe/models/staff_member.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MockApiForRealtime extends ApiService {
  int fetchOrdersCount = 0;

  @override
  Future<List<dynamic>> getMyOrders() async {
    fetchOrdersCount++;
    return [
      {
        'id': 'ord-101',
        'short_id': '101',
        'user_id': 'user-1',
        'items': [],
        'total_price': 45.0,
        'created_at': DateTime.now().toIso8601String(),
        'status': 'preparing',
      }
    ];
  }

  @override
  Future<List<dynamic>> getBranchOrders() async {
    fetchOrdersCount++;
    return [];
  }
}

class FakeRealtimeService extends RealtimeService {
  OrderRealtimeCallback? userCallback;
  OrderRealtimeCallback? branchCallback;
  String? subscribedUserId;
  String? subscribedBranchId;
  bool unsubscribed = false;

  @override
  Future<void> subscribeToUserOrders(String userId, OrderRealtimeCallback onOrderUpdated) async {
    subscribedUserId = userId;
    userCallback = onOrderUpdated;
  }

  @override
  Future<void> subscribeToBranchOrders(String branchId, OrderRealtimeCallback onOrderUpdated) async {
    subscribedBranchId = branchId;
    branchCallback = onOrderUpdated;
  }

  @override
  Future<void> unsubscribe() async {
    unsubscribed = true;
    userCallback = null;
    branchCallback = null;
  }

  void emitUserOrderUpdate(Map<String, dynamic> record) {
    userCallback?.call(record);
  }

  void emitBranchOrderUpdate(Map<String, dynamic> record) {
    branchCallback?.call(record);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('RealtimeService & OrderNotifier Realtime Integration', () {
    test('RealtimeService init handles empty or invalid config gracefully', () async {
      final realtime = RealtimeService();
      expect(realtime.isInitialized, false);
      expect(realtime.hasActiveSubscription, false);

      await realtime.init(url: '', anonKey: '');
      expect(realtime.isInitialized, false);

      await realtime.subscribeToUserOrders('u1', (_) {});
      await realtime.subscribeToBranchOrders('b1', (_) {});
      await realtime.unsubscribe();
    });

    test('Customer login triggers subscribeToUserOrders and realtime event updates orders', () async {
      final api = MockApiForRealtime();
      final auth = AuthNotifier(api);
      auth.loggedIn = true;
      auth.userId = 'user-1';
      auth.userEmail = 'cust@test.com';

      final cart = CartNotifier(api, auth);
      final wallet = WalletNotifier(api, auth);
      final fakeRealtime = FakeRealtimeService();

      final orderNotifier = OrderNotifier(
        api,
        auth,
        cart,
        wallet,
        realtime: fakeRealtime,
      );

      expect(fakeRealtime.subscribedUserId, 'user-1');

      // Simulate Realtime DB PostgresChange event
      fakeRealtime.emitUserOrderUpdate({'id': 'ord-101', 'status': 'ready'});
      await Future.delayed(const Duration(milliseconds: 50));

      expect(api.fetchOrdersCount, greaterThanOrEqualTo(1));
      expect(orderNotifier.orderHistory.isNotEmpty, true);
      expect(orderNotifier.orderHistory.first.id, 'ord-101');

      orderNotifier.dispose();
      expect(fakeRealtime.unsubscribed, true);
    });

    test('Barista login triggers subscribeToBranchOrders', () async {
      final api = MockApiForRealtime();
      final auth = AuthNotifier(api);
      auth.loggedIn = true;
      auth.role = UserRole.barista;
      auth.selectBranch('branch-kadikoy');

      final cart = CartNotifier(api, auth);
      final wallet = WalletNotifier(api, auth);
      final fakeRealtime = FakeRealtimeService();

      final orderNotifier = OrderNotifier(
        api,
        auth,
        cart,
        wallet,
        realtime: fakeRealtime,
      );

      expect(fakeRealtime.subscribedBranchId, 'branch-kadikoy');

      orderNotifier.dispose();
      expect(fakeRealtime.unsubscribed, true);
    });
  });
}
