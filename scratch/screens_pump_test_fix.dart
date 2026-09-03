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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    const channel = MethodChannel('OneSignal');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async => null);
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Widget wrapWithProvider(Widget child) {
    final api = DummyApi();
    final auth = AuthNotifier(api);
    final cart = CartNotifier(api, auth);
    final wallet = WalletNotifier(api, auth);
    final orders = OrderNotifier(api, auth, cart, wallet);
    final stock = StockNotifier(api, auth);
    final menu = MenuNotifier(api);
    final staff = StaffNotifier(api);
    final appState = AppState(auth, cart, orders, wallet, stock, menu, staff);

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
      await tester.pumpWidget(wrapWithProvider(screen));
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
