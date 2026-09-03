import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:emar_kafe/widgets/branch_picker.dart';
import 'package:emar_kafe/widgets/campaign_detail_sheet.dart';
import 'package:emar_kafe/widgets/product_detail_sheet.dart';
import 'package:emar_kafe/widgets/stock_manager_sheet.dart';
import 'package:emar_kafe/state/app_state.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/state/notifiers/auth_notifier.dart';
import 'package:emar_kafe/state/notifiers/cart_notifier.dart';
import 'package:emar_kafe/state/notifiers/order_notifier.dart';
import 'package:emar_kafe/state/notifiers/wallet_notifier.dart';
import 'package:emar_kafe/state/notifiers/staff_notifier.dart';
import 'package:emar_kafe/state/notifiers/stock_notifier.dart';
import 'package:emar_kafe/state/notifiers/menu_notifier.dart';
import 'package:emar_kafe/models/product.dart';
import 'package:emar_kafe/models/campaign.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

class DummyApi extends ApiService {
  @override Future<Map<String, dynamic>> getMe() async => {'user': {'email': 'a@a', 'role': 'customer'}};
  @override Future<Map<String, dynamic>> getProfile() async => {'full_name': 'A'};
  @override Future<List<dynamic>> getBranches() async => [{'id': 'b1', 'name': 'B1'}];
  @override Future<Map<String, dynamic>> getMenu({String? branchId, int page = 1, int limit = 20, String? categoryId, String? search}) async => {'data': []};
  @override Future<List<dynamic>> getCategories() async => [];
  @override Future<Map<String, dynamic>> getWalletBalance() async => {'data': {'balance': 100}};
  @override Future<Map<String, dynamic>> getCart() async => {'data': {'items': []}};
  @override Future<List<dynamic>> getMyOrders() async => [];
  @override Future<List<dynamic>> getFavorites() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    const channel = MethodChannel('OneSignal');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async => null);
  });

  testWidgets('Widgets interaction coverage', (tester) async {
    final api = DummyApi();
    final auth = AuthNotifier(api);
    final cart = CartNotifier(api, auth);
    final wallet = WalletNotifier(api, auth);
    final orders = OrderNotifier(api, auth, cart, wallet);
    final stock = StockNotifier(api, auth);
    final menu = MenuNotifier(api);
    final staff = StaffNotifier(api);
    final appState = AppState(auth, cart, orders, wallet, stock, menu, staff);

    auth.role = UserRole.customer;
    auth.loggedIn = true;
    
    final p1 = Product(id: 'p1', name: 'P1', category: ProductCategory.values.first, price: 10, icon: '', rating: 5, ratingCount: 1);
    final camp = Campaign(id: 'c1', title: 'Camp', subtitle: 'Sub', details: 'Det', badge: 'B', icon: '', colors: [Colors.red, Colors.blue]);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: appState),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: cart),
          ChangeNotifierProvider.value(value: wallet),
          ChangeNotifierProvider.value(value: orders),
          ChangeNotifierProvider.value(value: stock),
          ChangeNotifierProvider.value(value: menu),
          ChangeNotifierProvider.value(value: staff),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    key: const Key('branch'),
                    onPressed: () => showBranchPicker(context),
                    child: const Text('Branch'),
                  ),
                  ElevatedButton(
                    key: const Key('product'),
                    onPressed: () => showProductDetail(context, p1),
                    child: const Text('Product'),
                  ),
                  ElevatedButton(
                    key: const Key('campaign'),
                    onPressed: () => showCampaignDetail(context, camp),
                    child: const Text('Campaign'),
                  ),
                  ElevatedButton(
                    key: const Key('stock'),
                    onPressed: () => showStockManager(context),
                    child: const Text('Stock'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    
    // Tap Branch
    await tester.tap(find.byKey(const Key('branch')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // close sheet
    await tester.pumpAndSettle();
    
    // Tap Product
    await tester.tap(find.byKey(const Key('product')), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // close sheet
    await tester.pumpAndSettle();
    
    // Tap Campaign
    await tester.tap(find.byKey(const Key('campaign')), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // close sheet
    await tester.pumpAndSettle();
    
    // Tap Stock
    await tester.tap(find.byKey(const Key('stock')), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // close sheet
    await tester.pumpAndSettle();
    
    orders.dispose();
    auth.dispose();
    cart.dispose();
    wallet.dispose();
    stock.dispose();
    menu.dispose();
    staff.dispose();
    appState.dispose();
  });
}
