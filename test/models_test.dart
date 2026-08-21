import 'package:flutter_test/flutter_test.dart';
import 'package:emar_kafe/models/product.dart';
import 'package:emar_kafe/models/branch.dart';
import 'package:emar_kafe/models/order_record.dart';

void main() {
  group('Model Parsers & Deserialization Tests', () {
    test('Product.fromDb should parse database JSON correctly', () {
      final dbRow = {
        'id': 'prod-101',
        'name': 'Filtre Kahve',
        'category_id': 'cat-1',
        'base_price': 65.50,
        'icon': '☕',
        'avg_rating': 4.8,
        'rating_count': 120,
        'description': 'Taze demlenmiş Colombia çekirdekleri.',
        'is_active': true,
        'is_loyalty_eligible': true,
        'categories': {'name': 'Sıcak Kahve'},
      };

      final product = Product.fromDb(dbRow);

      expect(product.id, 'prod-101');
      expect(product.name, 'Filtre Kahve');
      expect(product.price, 65.50);
      expect(product.category, ProductCategory.hotCoffee);
      expect(product.isCoffee, true);
      expect(product.isDessert, false);
      expect(product.rating, 4.8);
      expect(product.ratingCount, 120);
    });

    test('Branch.fromDb should parse database JSON correctly', () {
      final branchRow = {
        'id': 'b-kadikoy',
        'name': 'Kadıköy Şubesi',
        'address': 'Moda Cad. No: 12',
        'is_active': true,
      };

      final branch = Branch.fromDb(branchRow);

      expect(branch.id, 'b-kadikoy');
      expect(branch.name, 'Kadıköy Şubesi');
      expect(branch.address, 'Moda Cad. No: 12');
      expect(branch.isActive, true);
    });

    test('OrderRecord.fromJson should parse orders correctly', () {
      final orderJson = {
        'id': 'ord-12345678-abcd',
        'status': 'preparing',
        'branch': 'Kadıköy',
        'customer_name': 'Ahmet Y.',
        'order_items': [
          {'product_id': 'p-latte', 'quantity': 2},
          {'product_id': 'p-cookie', 'quantity': 1},
        ],
        'created_at': '2026-08-14T12:00:00Z',
      };

      final order = OrderRecord.fromJson(orderJson);

      expect(order.id, 'ord-12345678-abcd');
      expect(order.shortId, 'ORD-1234');
      expect(order.manualStatus, OrderStatus.preparing);
      expect(order.items['p-latte'], 2);
      expect(order.items['p-cookie'], 1);
    });
  });
}
