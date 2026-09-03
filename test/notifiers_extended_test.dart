import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/state/app_state.dart';
import 'package:emar_kafe/models/campaign.dart';
import 'package:emar_kafe/models/staff_member.dart';
import 'package:emar_kafe/models/branch.dart';
import 'package:emar_kafe/state/notifiers/menu_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Extended Notifiers & AppState Tests', () {
    late ApiService api;
    late AuthNotifier auth;
    late CartNotifier cart;
    late WalletNotifier wallet;
    late OrderNotifier orders;
    late StockNotifier stock;
    late MenuNotifier menu;
    late StaffNotifier staff;
    late AppState app;

    setUp(() {
      api = ApiService();
      auth = AuthNotifier(api);
      cart = CartNotifier(api, auth);
      wallet = WalletNotifier(api, auth);
      orders = OrderNotifier(api, auth, cart, wallet);
      orders.stopPolling();
      stock = StockNotifier(api, auth);
      menu = MenuNotifier(api);
      staff = StaffNotifier(api);
      app = AppState(auth, cart, orders, wallet, stock, menu, staff);
    });

    test('Campaign management in AppState', () {
      final initialCount = app.campaignList.length;
      const testCampaign = Campaign(
        title: 'Özel İndirim',
        subtitle: 'Bugüne özel %20',
        details: 'Tüm ürünlerde geçerli',
        badge: 'YENİ',
        icon: '🎉',
        colors: [],
      );

      app.addCampaign(testCampaign);
      expect(app.campaignList.length, initialCount + 1);
      expect(app.campaignList.first.title, 'Özel İndirim');

      app.removeCampaign(testCampaign);
      expect(app.campaignList.length, initialCount);
    });

    test('Product rating helpers and state checking', () {
      expect(app.hasOrderedProduct('p-espresso'), false);
      expect(app.canRateProduct('p-espresso'), false);

      app.ratings['p-espresso'] = 5.0;
      expect(app.ratings['p-espresso'], 5.0);
    });

    test('StaffNotifier state and list mutations', () {
      expect(staff.isLoading, false);
      expect(staff.error, null);
      expect(staff.staffList.isEmpty, true);

      // Local mock injection for staff list
      staff.staffList = [
        StaffMember.fromJson({
          'id': 'st-mock-1',
          'full_name': 'Barista Ali',
          'role': 'barista',
          'created_at': '2026-08-20',
        }),
      ];
      expect(staff.staffList.length, 1);
      expect(staff.staffList.first.fullName, 'Barista Ali');
    });

    test('CartNotifier local calculations without API sync', () {
      expect(cart.cartCount, 0);
      expect(cart.cartTotal, 0.0);
    });

    test('Branch selection and name lookup in AppState', () {
      app.selectBranch('b-talas');
      expect(app.selectedBranchId, 'b-talas');
    });
  });
}
