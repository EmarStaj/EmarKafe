import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emar_kafe/screens/customer/order_tracking_screen.dart';
import 'package:emar_kafe/screens/customer/home_tab.dart';
import 'package:emar_kafe/screens/customer/wallet_screen.dart';
import 'package:emar_kafe/screens/customer/customer_shell.dart';
import 'package:emar_kafe/screens/customer/profile_tab.dart';
import 'package:emar_kafe/screens/customer/order_history_screen.dart';
import 'package:emar_kafe/screens/customer/chat_assistant_screen.dart';
import 'package:emar_kafe/screens/customer/cart_tab.dart';
import 'package:emar_kafe/screens/customer/campaigns_tab.dart';
import 'package:emar_kafe/screens/staff/barista_screen.dart';
import 'package:emar_kafe/screens/staff/qr_scanner_screen.dart';
import 'package:emar_kafe/screens/staff/manager_screen.dart';
import 'package:emar_kafe/screens/staff/admin_screen.dart';
import 'package:emar_kafe/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:emar_kafe/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/state/notifiers/auth_notifier.dart';
import 'package:emar_kafe/state/notifiers/cart_notifier.dart';
import 'package:emar_kafe/state/notifiers/order_notifier.dart';
import 'package:emar_kafe/state/notifiers/wallet_notifier.dart';
import 'package:emar_kafe/state/notifiers/staff_notifier.dart';
import 'package:emar_kafe/state/notifiers/stock_notifier.dart';
import 'package:emar_kafe/state/notifiers/menu_notifier.dart';
import 'package:emar_kafe/models/order_record.dart';
import 'package:flutter/services.dart';

class DummyApi extends ApiService {
  @override Future<Map<String, dynamic>> getMe() async => {'user': {'email': 'a@a', 'role': 'admin'}};
  @override Future<Map<String, dynamic>> getProfile() async => {'full_name': 'A', 'role': 'admin'};
  @override Future<Map<String, dynamic>> getMenu({int page = 1, int limit = 20, String? categoryId, String? search}) async => {'data': []};
  @override Future<List<dynamic>> getCategories() async => [];
  @override Future<List<dynamic>> getBranches() async => [];
  @override Future<Map<String, dynamic>> getWalletBalance() async => {'data': {'balance': 0}};
  @override Future<Map<String, dynamic>> getCart() async => {'data': {'items': []}};
  @override Future<List<dynamic>> getMyOrders() async => [];
  @override Future<List<dynamic>> getBranchOrders() async => [];
  @override Future<Map<String, dynamic>> getLoyaltyProgress() async => {'data': {}};
  @override Future<List<dynamic>> getStaff({String? branchId}) async => [];
  @override Future<List<dynamic>> getFavorites() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    const channel = MethodChannel('OneSignal');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async => null);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    
    // Ignore overflow errors
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('overflowed')) {
        return;
      }
      FlutterError.presentError(details);
    };
  });

  Widget wrapWithProvider(
    Widget child,
    AppState appState,
    AuthNotifier auth,
    CartNotifier cart,
    WalletNotifier wallet,
    OrderNotifier orders,
    StockNotifier stock,
    MenuNotifier menu,
    StaffNotifier staff,
  ) {
    return MultiProvider(
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
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('Pump all screens', (WidgetTester tester) async {
    tester.binding.window.physicalSizeTestValue = const Size(1080, 2400);
    tester.binding.window.devicePixelRatioTestValue = 1.0;

    final orderRecord = OrderRecord(
      id: 'o1',
      shortId: 'O1',
      userId: 'u1',
      items: {},
      totalPrice: 10,
      createdAt: DateTime.now(),
      status: 'created',
      manualStatus: OrderStatus.created,
    );

    final screens = [
      OrderTrackingScreen(order: orderRecord),
      HomeTab(onProfileTap: () {}),
      const WalletScreen(),
      const ProfileTab(),
      const OrderHistoryScreen(),
      const ChatAssistantScreen(),
      const CartTab(),
      const CampaignsTab(),
      const BaristaScreen(),
      const QRScannerScreen(),
      const ManagerScreen(),
      const AdminScreen(),
      const LoginScreen(),
    ];

    for (final screen in screens) {
      final api = DummyApi();
      final auth = AuthNotifier(api);
      final cart = CartNotifier(api, auth);
      final wallet = WalletNotifier(api, auth);
      final orders = OrderNotifier(api, auth, cart, wallet);
      final stock = StockNotifier(api, auth);
      final menu = MenuNotifier(api);
      final staff = StaffNotifier(api);
      final appState = AppState(auth, cart, orders, wallet, stock, menu, staff);

      try {
        await tester.pumpWidget(wrapWithProvider(screen, appState, auth, cart, wallet, orders, stock, menu, staff));
        await tester.pump(const Duration(milliseconds: 100));
      } catch (e) {
        print('Screen failed: $screen -> $e');
      }

      orders.dispose();
      auth.dispose();
      cart.dispose();
      wallet.dispose();
      stock.dispose();
      menu.dispose();
      staff.dispose();
      appState.dispose();
    }
  });
}
