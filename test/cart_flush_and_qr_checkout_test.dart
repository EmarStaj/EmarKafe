import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/models/product.dart';
import 'package:emar_kafe/models/cart_item.dart';
import 'package:emar_kafe/state/notifiers/auth_notifier.dart';
import 'package:emar_kafe/state/notifiers/cart_notifier.dart';
import 'package:emar_kafe/data/catalog.dart';

class MockApiForCart extends ApiService {
  MockApiForCart() : super();

  List<Map<String, dynamic>> serverCartItems = [];
  List<String> addedProducts = [];
  List<String> updatedCartItems = [];
  bool getCartCalled = false;

  @override
  String? get token => 'test-token';

  @override
  Future<Map<String, dynamic>> getCart() async {
    getCartCalled = true;
    return {
      'data': {
        'items': serverCartItems,
      }
    };
  }

  @override
  Future<List<String>> addToCart(
    String productId,
    int quantity, {
    List<dynamic>? options,
  }) async {
    addedProducts.add(productId);
    serverCartItems.add({
      'id': 'server-item-${serverCartItems.length + 1}',
      'product_id': productId,
      'quantity': quantity,
      'unit_price': 120.0,
      'selected_options': options ?? [],
      'products': {
        'id': productId,
        'name': 'Test Coffee',
        'base_price': 120.0,
        'category_id': 'cat1',
        'categories': {'name': 'Sıcak Kahve'}
      }
    });
    return [];
  }

  @override
  Future<void> updateCartItem(String cartItemId, int qty) async {
    updatedCartItems.add('$cartItemId:$qty');
    for (var item in serverCartItems) {
      if (item['id'] == cartItemId) {
        item['quantity'] = qty;
      }
    }
  }

  @override
  Future<Map<String, dynamic>> getWalletBalance() async {
    return {'data': {'balance': 500.0}};
  }

  @override
  Future<String> generateWalletToken() async {
    if (serverCartItems.isEmpty) {
      throw Exception('Cannot generate QR. Your cart is empty.');
    }
    return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test-qr-token';
  }
}

class MockAuthForCart extends AuthNotifier {
  MockAuthForCart(super.api);

  @override
  bool get loggedIn => true;

  @override
  String get userId => 'user-123';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CartNotifier & QR Checkout Synchronization Tests', () {
    late MockApiForCart mockApi;
    late MockAuthForCart mockAuth;
    late CartNotifier cartNotifier;

    setUp(() {
      mockApi = MockApiForCart();
      mockAuth = MockAuthForCart(mockApi);
      cartNotifier = CartNotifier(mockApi, mockAuth);
    });

    test('Adding product adds to local cart and syncs with backend via addToCart', () async {
      final testProd = Product(
        id: 'prod-uuid-1',
        name: 'Test Latte',
        category: ProductCategory.hotCoffee,
        price: 120,
        icon: '☕',
        rating: 5.0,
        ratingCount: 10,
      );
      Catalog.instance.registerProducts([testProd]);

      await cartNotifier.addToCart('prod-uuid-1');

      expect(cartNotifier.cartCount, 1);
      expect(cartNotifier.cart.containsKey('prod-uuid-1'), true);
      expect(mockApi.addedProducts.contains('prod-uuid-1'), true);
      expect(mockApi.getCartCalled, true);
      expect(cartNotifier.cartTotal, 120.0);
    });

    test('changeQty triggers debouncing and flushDebounces flushes updates immediately without losing cart', () async {
      final testProd = Product(
        id: 'prod-uuid-2',
        name: 'Test Espresso',
        category: ProductCategory.hotCoffee,
        price: 80,
        icon: '☕',
        rating: 4.8,
        ratingCount: 5,
      );
      Catalog.instance.registerProducts([testProd]);

      // Add to cart first
      await cartNotifier.addToCart('prod-uuid-2');
      expect(cartNotifier.cartCount, 1);

      // Rapidly increment quantity
      await cartNotifier.changeQty('prod-uuid-2', 1);
      await cartNotifier.changeQty('prod-uuid-2', 1);

      expect(cartNotifier.cartCount, 3);
      expect(cartNotifier.isUpdatingCart, true);

      // Immediately flush before the 1000ms debounce timer
      await cartNotifier.flushDebounces();

      expect(cartNotifier.isUpdatingCart, false);
      expect(cartNotifier.cartCount, 3);
      expect(mockApi.updatedCartItems.isNotEmpty, true);
    });

    test('QR token generation works seamlessly when cart has items', () async {
      final testProd = Product(
        id: 'prod-uuid-3',
        name: 'Test Mocha',
        category: ProductCategory.hotCoffee,
        price: 130,
        icon: '☕',
        rating: 4.9,
        ratingCount: 8,
      );
      Catalog.instance.registerProducts([testProd]);

      await cartNotifier.addToCart('prod-uuid-3');
      await cartNotifier.flushDebounces();

      expect(cartNotifier.cart.isNotEmpty, true);
      final qrToken = await mockApi.generateWalletToken();
      expect(qrToken, startsWith('ey'));
      expect(cartNotifier.cartCount, 1);
    });

    test('Product reconstructed from backend joined data if not in catalog initially', () async {
      mockApi.serverCartItems = [
        {
          'id': 'cart-item-remote',
          'product_id': 'remote-uuid-999',
          'quantity': 2,
          'unit_price': 150.0,
          'selected_options': [],
          'products': {
            'id': 'remote-uuid-999',
            'name': 'Remote Special Blend',
            'base_price': 150.0,
            'category_id': 'cat1',
            'categories': {'name': 'Sıcak Kahve'}
          }
        }
      ];

      await cartNotifier.fetchCart();

      expect(cartNotifier.cartCount, 2);
      expect(cartNotifier.cart.containsKey('remote-uuid-999'), true);
      expect(cartNotifier.cart['remote-uuid-999']!.product.name, 'Remote Special Blend');
      expect(cartNotifier.cartTotal, 300.0);
    });
  });
}
