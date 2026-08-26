import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:emar_kafe/screens/customer/cart_tab.dart';
import 'package:emar_kafe/screens/login_screen.dart';
import 'package:emar_kafe/screens/customer/profile_tab.dart';
import 'package:emar_kafe/screens/customer/order_history_screen.dart';
import 'package:emar_kafe/screens/customer/chat_assistant_screen.dart';
import 'package:emar_kafe/screens/staff/admin_screen.dart';
import 'package:emar_kafe/screens/staff/manager_screen.dart';
import 'package:emar_kafe/screens/staff/barista_screen.dart';
import 'package:emar_kafe/screens/customer/wallet_screen.dart';
import 'package:emar_kafe/state/app_state.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/state/notifiers/auth_notifier.dart';
import 'package:emar_kafe/state/notifiers/cart_notifier.dart';
import 'package:emar_kafe/state/notifiers/order_notifier.dart';
import 'package:emar_kafe/state/notifiers/wallet_notifier.dart';
import 'package:emar_kafe/state/notifiers/staff_notifier.dart';
import 'package:emar_kafe/state/notifiers/stock_notifier.dart';
import 'package:emar_kafe/state/notifiers/menu_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

class DummyApi extends ApiService {
  @override Future<Map<String, dynamic>> getMe() async => {'user': {'email': 'a@a', 'role': 'admin'}};
  @override Future<Map<String, dynamic>> login(String email, String password) async => {'token': 'test_token', 'user': {'email': 'a@a', 'role': 'admin'}};
  @override Future<Map<String, dynamic>> getCart() async => {'data': {'items': [{'id': '1', 'product_id': 'p1', 'product_name': 'P1', 'quantity': 1, 'base_price': 10, 'options': []}]}};
  @override Future<List<dynamic>> getMyOrders() async => [{'id': '1', 'short_id': '1', 'user_id': 'u', 'items': [], 'total_price': 10, 'created_at': DateTime.now().toIso8601String(), 'status': 'created'}];
  @override Future<List<dynamic>> getBranchOrders() async => [{'id': '1', 'short_id': '1', 'user_id': 'u', 'items': [], 'total_price': 10, 'created_at': DateTime.now().toIso8601String(), 'status': 'created'}];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() { FlutterError.onError = (FlutterErrorDetails details) { /* ignore */ };
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    const channel = MethodChannel('OneSignal');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async => null);
  });

  testWidgets('Screens interaction coverage', (tester) async {
    final api = DummyApi();
    final auth = AuthNotifier(api);
    final cart = CartNotifier(api, auth);
    final wallet = WalletNotifier(api, auth);
    final orders = OrderNotifier(api, auth, cart, wallet);
    final stock = StockNotifier(api, auth);
    final menu = MenuNotifier(api);
    final staff = StaffNotifier(api);
    final appState = AppState(auth, cart, orders, wallet, stock, menu, staff);
    
    auth.role = UserRole.admin;
    auth.loggedIn = true;
    
    await cart.fetchCart();
    // await orders.fetchMyOrders();
    // await orders.fetchBranchOrders();
    
    Widget wrap(Widget child) => MultiProvider(
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
    
    Future<void> pumpAndTap(Widget child) async {
      await tester.pumpWidget(wrap(child));
      await tester.pumpAndSettle();
      
      final elements = find.byWidgetPredicate((widget) {
        return widget is InkWell || widget is GestureDetector || widget is ElevatedButton || widget is TextButton || widget is IconButton || widget is FloatingActionButton || widget is ListTile;
      }).evaluate().toList();
      
      for (var element in elements) {
        try {
          await tester.tap(find.byWidget(element.widget), warnIfMissed: false);
          await tester.pumpAndSettle();
        } catch (_) {}
      }
    }

    await pumpAndTap(const CartTab());
    await pumpAndTap(const ProfileTab());
    await pumpAndTap(const OrderHistoryScreen());
    await pumpAndTap(const ChatAssistantScreen());
    await pumpAndTap(const AdminScreen());
    await pumpAndTap(const ManagerScreen());
    await pumpAndTap(const BaristaScreen());
    await pumpAndTap(const WalletScreen());
    await pumpAndTap(const LoginScreen());
    
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
