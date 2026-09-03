import 'package:flutter_test/flutter_test.dart';
import 'package:emar_kafe/models/campaign.dart';
import 'package:emar_kafe/models/product.dart';
import 'package:emar_kafe/models/cart_item.dart';
import 'package:emar_kafe/models/order_record.dart';

void main() {
  group('Comprehensive Models Tests', () {
    test('Campaign model coverage', () {
      final db = {
        'id': 'c-1',
        'title': 'T',
        'subtitle': 'S',
        'details': 'D',
        'badge': null,
        'icon': null,
        'color_start': '#AABBCC',
        'color_end': 'DDEEFF',
      };
      final campaign = Campaign.fromDb(db);
      expect(campaign.id, 'c-1');
      expect(campaign.badge, 'KAMPANYA');
      expect(campaign.icon, '🎁');
      expect(campaign.colors.length, 2);
    });

    test('Product model coverage', () {
      final db = {
        'id': 'p-1',
        'name': 'P',
        'category_id': 'c-1',
        'base_price': 10.0,
        'rating': 4.5,
        'options': [
          {'id': 'o-1', 'name': 'O1', 'price_delta': 2.0}
        ]
      };
      final product = Product.fromDb(db);
      expect(product.rating, 4.5);
      expect(product.options.length, 1);
      expect(product.options.first.id, 'o-1');
    });

    test('CartItem model coverage', () {
      final product = Product(id: 'p-1', name: 'P', category: ProductCategory.hotCoffee, price: 10.0, icon: '☕', rating: 4.5, ratingCount: 1);
      final item = CartItem(cartItemId: 'c-1', product: product, quantity: 1);
      final copied = item.copyWith(); // pass nulls
      expect(copied.cartItemId, 'c-1');
      expect(copied.quantity, 1);
      
      final emptyOptionsItem = CartItem(cartItemId: 'c-1', product: product, quantity: 1, selectedOptions: [ProductOption(id: 'o', name: 'n', priceDelta: -20)]);
      expect(emptyOptionsItem.unitPrice, 0); // test negative delta clamping
    });

    test('OrderRecord model coverage', () {
      final db = {
        'id': 'ord-12',
        'user_id': 'u-1',
        'items': {'p-1': 2},
        'status': 'pending_qr',
        'created_at': null,
        'qr_token': 'token123'
      };
      final order = OrderRecord.fromJson(db);
      expect(order.total, 0.0);
      expect(order.branch, null);
      expect(order.isPendingQR, true);
      expect(order.remainingSeconds, 300);
      expect(order.qrToken, 'token123');

      final prepDessert = OrderRecord.computePrep({'p-dessert-dummy': 1}, DateTime(2026, 1, 1, 12, 0));
      expect(prepDessert, 2); // default logic might return 2

      // Let's test prep time branching
      // We can't mock Catalog easily here unless we inject it, but it catches exception and ignores.
      // We can use a product from Catalog.instance if it's initialized, else it catches.
      
      final order2 = OrderRecord.fromJson({'id': 'ord', 'user_id': 'u-1', 'items': {'p-latte': 2}, 'status': 'completed', 'total_price': 50.0});
      expect(order2.pickedUp, true);
    });
  });
}
