import 'package:flutter_test/flutter_test.dart';
import 'package:emar_kafe/models/product.dart';
import 'package:emar_kafe/models/cart_item.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/state/notifiers/auth_notifier.dart';
import 'package:emar_kafe/state/notifiers/cart_notifier.dart';
import 'package:emar_kafe/state/notifiers/order_notifier.dart';
import 'package:emar_kafe/state/notifiers/wallet_notifier.dart';
import 'package:emar_kafe/data/catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MockApiForReward extends ApiService {
  String? redeemedRewardId;

  @override
  String? get token => 'mock-token';

  @override
  Future<Map<String, dynamic>> getMe() async => {'user': {'id': 'u1', 'email': 'a@a', 'role': 'customer'}};

  @override
  Future<Map<String, dynamic>> getProfile() async => {'full_name': 'Test User', 'role': 'customer'};

  @override
  Future<Map<String, dynamic>> getCart() async => {'data': {'items': []}};

  @override
  Future<Map<String, dynamic>> getLoyaltyProgress() async => {
        'data': {
          'progress': [
            {'current_count': 0, 'threshold': 4}
          ],
          'rewards': [
            {'id': 'reward-uuid-999', 'status': 'earned'}
          ]
        }
      };

  @override
  Future<void> redeemLoyaltyReward(String rewardId, {String? branchId}) async {
    redeemedRewardId = rewardId;
  }
}

class MockAuthForReward extends AuthNotifier {
  MockAuthForReward(super.api);

  @override
  bool get loggedIn => true;

  @override
  UserRole get role => UserRole.customer;

  @override
  String get userId => 'user-123';

  @override
  Future<void> init() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Free Coffee Reward System Tests', () {
    late MockApiForReward mockApi;
    late MockAuthForReward auth;
    late CartNotifier cart;
    late WalletNotifier wallet;
    late OrderNotifier orders;

    setUp(() {
      mockApi = MockApiForReward();
      auth = MockAuthForReward(mockApi);

      cart = CartNotifier(mockApi, auth);
      wallet = WalletNotifier(mockApi, auth);
      orders = OrderNotifier(mockApi, auth, cart, wallet);
      orders.stopPolling();
    });

    tearDown(() {
      orders.dispose();
      auth.dispose();
      cart.dispose();
      wallet.dispose();
    });

    test('Identifies the most expensive coffee item and calculates discount correctly', () async {
      const pAmericano = Product(
        id: 'p-americano',
        name: 'Americano',
        category: ProductCategory.hotCoffee,
        price: 45.0,
        icon: '☕',
        rating: 4.8,
        ratingCount: 10,
      );

      const pLatte = Product(
        id: 'p-latte',
        name: 'Latte',
        category: ProductCategory.hotCoffee,
        price: 60.0,
        icon: '🥛',
        rating: 4.9,
        ratingCount: 15,
      );

      const pMocha = Product(
        id: 'p-mocha',
        name: 'Mocha',
        category: ProductCategory.hotCoffee,
        price: 85.0,
        icon: '🍫',
        rating: 5.0,
        ratingCount: 20,
      );

      const pCheesecake = Product(
        id: 'p-cake',
        name: 'San Sebastian',
        category: ProductCategory.dessert,
        price: 120.0,
        icon: '🍰',
        rating: 4.9,
        ratingCount: 30,
      );

      Catalog.instance.registerProducts([pAmericano, pLatte, pMocha, pCheesecake]);

      // Add all 4 items to cart
      cart.cart['p-americano'] = CartItem(cartItemId: 'item-1', product: pAmericano, quantity: 1);
      cart.cart['p-latte'] = CartItem(cartItemId: 'item-2', product: pLatte, quantity: 1);
      cart.cart['p-mocha'] = CartItem(cartItemId: 'item-3', product: pMocha, quantity: 1);
      cart.cart['p-cake'] = CartItem(cartItemId: 'item-4', product: pCheesecake, quantity: 1);
      cart.cartTotal = 45.0 + 60.0 + 85.0 + 120.0; // 310.0

      // Most expensive COFFEE should be Mocha (85₺), not Cheesecake (dessert)
      expect(cart.mostExpensiveCoffeeItem?.product.id, 'p-mocha');
      expect(cart.mostExpensiveCoffeeItem?.unitPrice, 85.0);

      // When toggle is off
      expect(cart.useFreeCoffeeReward, false);
      expect(cart.freeCoffeeDiscount, 0.0);
      expect(cart.effectiveCartTotal, 310.0);

      // Turn on free coffee reward
      cart.setUseFreeCoffeeReward(true);
      expect(cart.useFreeCoffeeReward, true);
      expect(cart.freeCoffeeDiscount, 85.0);
      expect(cart.effectiveCartTotal, 225.0); // 310 - 85 = 225.0
    });

    test('OrderNotifier fetches available reward and redeems it', () async {
      await orders.fetchLoyalty();

      expect(orders.freeCoffeesEarned, 1);
      expect(orders.availableRewardId, 'reward-uuid-999');

      await orders.redeemAvailableReward(branchId: 'branch-1');
      expect(mockApi.redeemedRewardId, 'reward-uuid-999');
    });
  });
}
