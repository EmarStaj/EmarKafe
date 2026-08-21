import 'package:flutter_test/flutter_test.dart';
import 'package:emar_kafe/models/staff_member.dart';
import 'package:emar_kafe/models/campaign.dart';
import 'package:emar_kafe/models/product.dart';
import 'package:emar_kafe/models/cart_item.dart';
import 'package:emar_kafe/models/branch.dart';
import 'package:emar_kafe/models/order_record.dart';
import 'package:emar_kafe/theme.dart';

void main() {
  group('Extended Frontend Model Tests', () {
    test('StaffMember deserialization and roleLabel helper', () {
      final jsonBarista = {
        'id': 'st-1',
        'full_name': 'Ali Veli',
        'email': 'ali@emar.com',
        'role': 'barista',
        'branch_id': 'b-1',
        'branch_name': 'Talas',
        'created_at': '2026-08-20T10:00:00Z',
      };
      final barista = StaffMember.fromJson(jsonBarista);
      expect(barista.id, 'st-1');
      expect(barista.fullName, 'Ali Veli');
      expect(barista.email, 'ali@emar.com');
      expect(barista.role, 'barista');
      expect(barista.roleLabel, 'Barista');
      expect(barista.branchName, 'Talas');

      final jsonManager = {
        'id': 'st-2',
        'name': 'Ayşe Yönetici',
        'role': 'branch_manager',
        'created_at': '2026-08-20T10:00:00Z',
      };
      final manager = StaffMember.fromJson(jsonManager);
      expect(manager.fullName, 'Ayşe Yönetici');
      expect(manager.roleLabel, 'Şube Müdürü');

      final jsonAdmin = {
        'id': 'st-3',
        'role': 'admin',
        'created_at': '2026-08-20T10:00:00Z',
      };
      final admin = StaffMember.fromJson(jsonAdmin);
      expect(admin.fullName, 'İsimsiz');
      expect(admin.roleLabel, 'Admin');

      final jsonOther = {
        'id': 'st-4',
        'role': 'cashier',
        'created_at': '2026-08-20T10:00:00Z',
      };
      final other = StaffMember.fromJson(jsonOther);
      expect(other.roleLabel, 'cashier');
    });

    test('Campaign model properties and defaults', () {
      const campaign = Campaign(
        title: '2. Kahve %50',
        subtitle: 'Tüm filtre kahvelerde geçerli',
        details: 'Detaylar ve koşullar...',
        badge: 'FIRSAT',
        icon: '☕',
        colors: [EmarColors.paprika, EmarColors.paprikaDim],
      );

      expect(campaign.title, '2. Kahve %50');
      expect(campaign.subtitle, 'Tüm filtre kahvelerde geçerli');
      expect(campaign.details, 'Detaylar ve koşullar...');
      expect(campaign.badge, 'FIRSAT');
      expect(campaign.icon, '☕');
      expect(campaign.colors.length, 2);
    });

    test('ProductOption deserialization and toJson', () {
      final jsonOpt = {
        'id': 'opt-syrup',
        'name': 'Vanilya Şurubu',
        'price_delta': 15.0,
      };

      final option = ProductOption.fromJson(jsonOpt);
      expect(option.id, 'opt-syrup');
      expect(option.name, 'Vanilya Şurubu');
      expect(option.priceDelta, 15.0);
      expect(option.toJson()['price_delta'], 15.0);
    });

    test('CartItem price calculation and copyWith', () {
      const product = Product(
        id: 'p-latte',
        name: 'Latte',
        category: ProductCategory.hotCoffee,
        price: 70.0,
        icon: '☕',
        rating: 4.8,
        ratingCount: 15,
      );

      const optVanilla = ProductOption(
        id: 'opt-v',
        name: 'Vanilya',
        priceDelta: 10.0,
      );

      final item = CartItem(
        cartItemId: 'c-item-1',
        product: product,
        quantity: 2,
        selectedOptions: [optVanilla],
      );

      expect(item.unitPrice, 80.0);
      expect(item.totalPrice, 160.0);

      final updated = item.copyWith(quantity: 3);
      expect(updated.quantity, 3);
      expect(updated.totalPrice, 240.0);
      expect(updated.cartItemId, 'c-item-1');
    });

    test('Branch model opening_hours and working_hours fallback', () {
      final rowWithOpening = {
        'id': 'b-talas',
        'name': 'Talas Şubesi',
        'opening_hours': {'monday': '08:00-22:00'},
        'is_active': true,
      };
      final b1 = Branch.fromDb(rowWithOpening);
      expect(b1.name, 'Talas Şubesi');
      expect(b1.workingHours?['monday'], '08:00-22:00');

      final rowWithWorking = {
        'id': 'b-melikgazi',
        'name': 'Melikgazi Şubesi',
        'working_hours': {'sunday': '09:00-23:00'},
        'is_active': false,
      };
      final b2 = Branch.fromDb(rowWithWorking);
      expect(b2.workingHours?['sunday'], '09:00-23:00');
      expect(b2.isActive, false);
    });

    test('OrderRecord computedStatus and prep minutes calculation', () {
      final json = {
        'id': 'ord-test-99',
        'status': 'ready',
        'branch': 'Kayseri',
        'customer_name': 'Zeynep K.',
        'order_items': [
          {'product_id': 'p-latte', 'quantity': 1},
        ],
        'created_at': DateTime.now().toIso8601String(),
      };

      final record = OrderRecord.fromJson(json);
      expect(record.computedStatus, OrderStatus.ready);
      expect(record.shortId, 'ORD-TEST');
      expect(record.pickedUp, false);

      final prep = OrderRecord.computePrep({'p-latte': 2}, DateTime.now());
      expect(prep, greaterThanOrEqualTo(2));
    });
  });
}
